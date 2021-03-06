=begin todo

Base class like Net::Cmd make some of the response parsing code
reusable for SMTP and NNTP.

Access files relative to current directory after login.  This is how
RFC 1738 says that ftp: URLs should be interpreted.  This is now how
popular browsers do it.  They interpret the first "/" of the URL-path
literally.  Option for enabling this behaviour??

Is there a better way to implement HEAD???  Currently we do RETR and
then send ABOR on the first 1xx reponse.  If only SIZE/MDTM did return
a different response for not-found and directories :-(

Set IdleTimeout when we go Idle.

Use CWD to locate directory when server is not UNIX.  RFC1738 says
that there is no general reliable way to get to another directory once
this is done, i.e. one must disconnect after this.

Implement ;type=a perhaps

If file name ends with "/" assume that it is a directory and skip RETR
(go for LIST right away.)

=end todo

=cut

package LWP::Conn::FTP;

# $Id: FTP.pm,v 1.17 1998/07/05 22:20:51 aas Exp $

# Copyright 1997-1998 Gisle Aas.
#
# This library is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use IO::Socket ();
use LWP::MainLoop qw(mainloop);
use strict;

use vars qw($DEBUG @ISA);
@ISA=qw(IO::Socket::INET);

sub new
{
    my($class, %cnf) = @_;

    my $mgr = delete $cnf{ManagedBy} ||
      Carp::croak("'ManagedBy' is mandatory");
    my $host =   delete $cnf{Host} || delete $cnf{PeerAddr} ||
      Carp::croak("'Host' is mandatory for FTP");

    my $port;
    $port = $1 if $host =~ s/:(\d+)//;
    $port = delete $cnf{Port} || delete $cnf{PeerPort} || $port || 21;

    my $timeout = delete $cnf{Timeout} || 5*60;
    my $idle_timeout = delete $cnf{IdleTimeout} || $timeout;
    my $conn_timeout = delete $cnf{ConnTimeout} || $timeout;
    my $req_limit = delete $cnf{ReqLimit} || 4;

    if (%cnf && $^W) {
	for (keys %cnf) {
	    warn "Unknown LWP::Conn::FTP->new attribute '$_' ignored\n";
	}
    }

    return LWP::Conn::_Connect->new($host, $port, $conn_timeout,
				   "LWP::Conn::FTP::Start",
				    [$mgr, $req_limit, $timeout, $idle_timeout]
				   );
}

sub state
{
    my($self, $state) = @_;
    print "STATE: $state\n" if $DEBUG && $DEBUG > 1;
    my $class = "LWP::Conn::FTP::$state";
    bless $self, $class;
}

sub inactive
{
    my $self = shift;
    $self->_error("Timeout");
}


sub error
{
    my($self, $msg) = @_;
    $self->_error("$msg: " . $self->message);
}

sub _error
{
    my($self, $msg) = @_;
    chomp($msg);
    print STDERR "ERROR: $msg\n";
    mainloop->forget($self);
    $self->close;
    if (my $data = delete *$self->{'lwp_data'}) {
	$data->close;
    }
    *$self->{'lwp_mgr'}->connection_closed($self);
    if (my $req = delete *$self->{'lwp_req'}) {
	$req->give_response(590, $msg);
    }
}

sub readable
{
    my $self = shift;
    my $buf = \ *$self->{'lwp_rbuf'};
    my $n = sysread($self, $$buf, 2048, length($$buf));
    if (!defined($n)) {
	$self->_error("Bad read: $!");
    } elsif ($n == 0) {
	$self->_error("EOF");
    } else {
	$self->check_rbuf;
    }
}

sub check_rbuf
{
    my $self = shift;
    my $buf = \ *$self->{'lwp_rbuf'};
    if (length $$buf) {
	my @lines = split(/\015?\012/, $$buf);
	if (substr($$buf, -1, 1) ne "\012") {
	    # the last line was not complete
	    *$self->{'lwp_rbuf'} = pop @lines;
	} else {
	    *$self->{'lwp_rbuf'} = "";
	}
	push(@{*$self->{'lwp_lines'}}, @lines);
    }
    $self->parse_response;
}

sub parse_response
{
    my $self = shift;
    my($code, $more, @res);
    while (@{*$self->{'lwp_lines'}}) {
	my $line = shift @{*$self->{'lwp_lines'}};
	if ($line =~ /^(\d\d\d)([\-\s])/) {
	    $more = $2 eq "-";
	    if ($code) {
                $more++ if $code ne $1;
	    } else {
		$code = $1;
	    }
	} elsif (!$code) {
	    push(@res, $line);
	    return $self->reponse_error(join("\n", @res));
	}
	push(@res, $line);
	last unless $more;
    }
    if ($more) {
	unshift(@{*$self->{'lwp_lines'}}, @res);
    } elsif ($code) {
	*$self->{'lwp_response_code'} = $code;
	*$self->{'lwp_response_mess'} = \@res;
	print STDERR "   <===\t", join("\n\t", @res), "\n" if $DEBUG;
	$self->response(substr($code, 0, 1), $code);
	$self->parse_response;
    }
}

sub response_error
{
    my($self, $bad_response) = @_;
    print STDERR "FTP: Bad server response '$bad_response' ignored\n";
}

sub code
{
    my $self = shift;
    *$self->{'lwp_response_code'} || "000";
}

sub message
{
    my $self = shift;
    wantarray ? @{*$self->{'lwp_response_mess'}}
              : join("\n", @{*$self->{'lwp_response_mess'}}, "");
}

sub response
{
    my($self, $r, $code, $mess) = @_;
    print STDERR "Response $code ignored\n";
}

sub send_cmd
{
    my($self, $cmd, $next_state) = @_;
    if ($DEBUG) {
	my $out = $cmd;
	$out =~ s/^(PASS\s+)(.+)/$1 . "*" x length($2)/e;
	print STDERR "===>\t$out\n";
    }
    $cmd .= "\015\012";
    # XXX should really wait for the socket to become writable, but
    # it is very unlikely that it should not be that.
    my $n = $self->syswrite($cmd, length($cmd));
    $self->_error("Can't syswrite ($n)") if !$n || $n != length($cmd);
    $self->state($next_state) if $next_state;
}

sub activate
{
}

sub stop
{
    my $self = shift;
    $self->_error("STOP");
}

sub login_info
{
    my($self, $req) = @_;
    my $url = $req->url;
    my($user,$pass) = $req->authorization_basic;
    $user ||= $url->user || "anonymous";
    $pass ||= $url->password || "nobody@";
    my $acct = $req->header("Account") || "home";
    ($user, $pass, $acct);
}

sub give_response
{
    my($self, $code, $mess, $more) = @_;
    my $req = delete *$self->{'lwp_req'};
    if (ref($more) || !defined($more)) {
	$more->{Server} = *$self->{'lwp_server_product'};
    }
    $req->give_response($code, $mess, $more);
    $self->activate;
}


package LWP::Conn::FTP::Start;
use base 'LWP::Conn::FTP';
use LWP::MainLoop qw(mainloop);

sub connected
{
    my($self, $param) = @_;
    @{*$self}{'lwp_mgr', 'lwp_rlim',
              'lwp_timeout', 'lwp_idle_timeout'} = @$param;
    *$self->{'lwp_type'} = "";
    *$self->{'lwp_rbuf'} = "";
    mainloop->readable($self);
    mainloop->timeout($self, *$self->{'lwp_idle_timeout'});
    $self->activate;
}

sub connect_failed
{
    my($self, $msg, $param) = @_;
    my $mgr = shift @$param;
    while (my $req = $mgr->get_request($self)) {
	$req->give_response(590, $msg);
    }
    $mgr->connection_closed($self);
}

sub response
{
    my($self, $r) = @_;
    $self->error("Bad welcome") unless $r eq "2";
    my $mess = $self->message;
    *$self->{'lwp_greeting'} = $mess;
    # Try to make it into a HTTP product token
    $mess =~ s/^\d+\s+//;
    $mess =~ s/^[\w\.]+\s+//;  # host name
    $mess =~ s/\s+ready\.?\s+$//;
    $mess =~ s/\s+\(Version\s+/\// && $mess =~ s/\)$//;
    *$self->{'lwp_server_product'} = $mess;
    $self->send_cmd("SYST" => "Syst");
}


package LWP::Conn::FTP::Syst;
use base 'LWP::Conn::FTP';

sub response
{
    my($self, $r) = @_;
    if ($r eq "2") {
	chomp(my $mess = $self->message);
	*$self->{'lwp_syst'} = $mess;
	$mess =~ s/^\d+\s+//;
	*$self->{'lwp_unix'}++ if $mess =~ /\bUNIX\b/i;
	*$self->{'lwp_server_product'} .= " ($mess)";
    }
    *$self->{'lwp_idle'}++;
    $self->state("Outlogged");
    $self->activate;
}


package LWP::Conn::FTP::Outlogged;
use base 'LWP::Conn::FTP';

sub activate
{
    my $self = shift;
    my $req = *$self->{'lwp_mgr'}->get_request;
    if (!$req) {
	*$self->{'lwp_idle'}++;
	*$self->{'lwp_mgr'}->connection_idle($self);
	return;
    } elsif (*$self->{'lwp_idle'}) {
	*$self->{'lwp_idle'} = 0;
	*$self->{'lwp_mgr'}->connection_active($self);
    }
    *$self->{'lwp_req'} = $req;
    (*$self->{'lwp_user'}, *$self->{'lwp_pass'}, *$self->{'lwp_acct'})
	= $self->login_info($req);
    $self->send_cmd("USER " . *$self->{'lwp_user'} => "User");
}


package LWP::Conn::FTP::User;
use base 'LWP::Conn::FTP';

sub response
{
    my($self, $r) = @_;
    if ($r eq "3") {
	my $pass = *$self->{'lwp_pass'};
	$self->send_cmd("PASS $pass" => "Pass");
    } elsif ($r eq "2") {
	$self->login_complete;
    } else {
	$self->cant_login;
    }
}

sub login_complete
{
    my $self = shift;
    $self->state("Ready");
    $self->activate;
}

sub cant_login
{
    my $self = shift;
    my $mess = $self->message;
    $mess =~ s/^\d+\s+//;
    chomp($mess);
    $self->state("Outlogged");
    $self->give_response(401, $mess,
			{"WWW-Authenticate" => 'Basic realm="FTP"',
			});
    $self->activate;
}


package LWP::Conn::FTP::Pass;
use base 'LWP::Conn::FTP::User';
sub response
{
    my($self, $r) = @_;
    if ($r eq "3") {
	my $acct = *$self->{'lwp_acct'};
	$self->send_cmd("ACCT $acct" => "Acct");
    } elsif ($r eq "2") {
	$self->login_complete;
    } else {
	$self->cant_login;
    }
}


package LWP::Conn::FTP::Acct;
use base 'LWP::Conn::FTP::User';
sub response
{
    my($self, $r) = @_;
    if ($r eq "2") {
	$self->login_complete;
    } else {
	$self->cant_login;
    }
}


package LWP::Conn::FTP::Rein;
use base 'LWP::Conn::FTP';

sub response
{
    my($self, $r) = @_;
    if ($r eq "2") {
	$self->send_cmd("USER " . *$self->{'lwp_user'} => "User");
    } else {
	if (my $req = delete *$self->{'lwp_req'}) {
	    *$self->{'lwp_mgr'}->pushback_request($self, $req);
	}
	$self->error("Can't reinitialize");
    }
}


package LWP::Conn::FTP::Type;
use base 'LWP::Conn::FTP';

sub response
{
    my($self, $r) = @_;
    if ($r eq "2") {
	$self->state("Ready");
	$self->activate;
    } else {
	$self->error("Can't set TYPE");
    }
}


package LWP::Conn::FTP::Ready;
use base 'LWP::Conn::FTP';
use LWP::MainLoop qw(mainloop);


sub type
{
    my($self, $type) = @_;
    return 1 if *$self->{'lwp_type'} eq $type;
    *$self->{'lwp_type'} = $type;
    $self->send_cmd("TYPE $type" => "Type");
    0;
}

sub activate
{
    my $self = shift;

    my $req = *$self->{'lwp_req'};
    unless ($req) {
	$req = *$self->{'lwp_mgr'}->get_request;
	if (!$req) {
	    *$self->{'lwp_idle'}++;
	    *$self->{'lwp_mgr'}->connection_idle($self);
	    return;
	} 
	elsif (*$self->{'lwp_idle'}) {
	    *$self->{'lwp_idle'} = 0;
	    *$self->{'lwp_mgr'}->connection_active($self);
	}
	*$self->{'lwp_req'} = $req;
	my($user, $pass, $acct) = $self->login_info($req);
	if ($user ne *$self->{'lwp_user'}) {
	    (*$self->{'lwp_user'}, *$self->{'lwp_pass'}, *$self->{'lwp_acct'})
		= ($user, $pass, $acct);
	    $self->send_cmd("REIN" => "Rein");
	    return;
	}
    }

    # We now have a request to perform and is logged in as the correct
    # user.
    my $method = uc($req->method);
    my $file = $req->url->path;
    if ($method =~ /^(GET|HEAD|PUT)$/) {
	# It would be nice to also support APPEND, PUT-UNIQUE
	return unless $self->type("I");  # we always use binary transfer mode

	$self->file_trans($method, $file);
	return;

	my @cwd = qw();
	if (@cwd) {
	    @{*$self->{'lwp_cwd'}} = @cwd;
	    $self->state("Cwd");
	    $self->cwd;
	    return;
	} else {
	    $self->cwd_done;
	}

    } elsif ($method eq "DELETE") {
	$self->send_cmd("DELE $file" => "Dele");

    } elsif ($method eq "RENAME") {
	$self->give_response(501, "RENAME not implemented yet");

    } elsif ($method eq "TRACE") {
	my $req = delete *$self->{'lwp_req'};
	my $res = $req->new_response(200, "OK");
	$res->date(time);
	$res->server(*$self->{'lwp_server_product'});
	$res->content_type("message/http");
	$res->content($req->as_string);
	$req->response_done($res);
	$self->activate;

    } else {
	$self->give_response(501, "Method not implemented");
    }
}

sub cwd_done
{
    # now we want to actually try to fetch the file
    # we could start by running SIZE, MDTM and such to get header
    # information and also to check if the file is there.
    my $self = shift;

}

sub file_trans
{
    my($self, $method, $file) = @_;
    *$self->{'lwp_meth'} = $method;
    *$self->{'lwp_file'} = $file;

    my $res = *$self->{'lwp_req'}->new_response(200, "OK");
    $res->date(time);
    $res->server(*$self->{'lwp_server_product'});
    # XXX we should guess content_type and such here
    *$self->{'lwp_res'} = $res;

    if ($method eq "PUT") {
	$self->port("W");
    } else {
	unless (*$self->{'lwp_noSIZE'}) {
	    $self->send_cmd("SIZE $file" => "Size");
	    return;
	}
	unless (*$self->{'lwp_noMDTM'}) {
	    $self->send_cmd("MDTM $file" => "Mdtm");
	    return;
	}
	$self->port(0);
    }
}

sub port
{
    my($self, $write) = @_;
    my $data = IO::Socket::INET->new(Listen => 1,
				     LocalAddr => $self->sockhost,
                                    );
    *$self->{'lwp_done'} = 0;
    if ($data) {
	my $port = $data->sockport;
	$port = ($port >> 8) . "," . ($port & 0xFF);
	$port = join(",", split(/\./, $data->sockhost)) . ",$port";
	$self->send_cmd("PORT $port" => "Port");
	bless $data, "LWP::Conn::FTP::Data::Listen";  # 4 level name - whow!!
	mainloop->readable($data);
	*$data->{'lwp_write'} = *$self->{'lwp_req'}->content_ref if $write;
	# A little circular reference makes life more interesting...
	*$data->{'lwp_ftp'} = $self;
	*$self->{'lwp_data'} = $data;
    } else {
	$self->_error("Can't create passive data socket");
    }
}

use Socket qw(MSG_OOB);

sub abort
{
    my $self = shift;
    send($self, "\377\364", 0);        # TELNET: IAC, IP
    send($self, "\377\362", MSG_OOB);  # TELNET: IAC, DM
    $self->send_cmd("ABOR");
    if (my $data = delete *$self->{'lwp_data'}) {
	$data->close;
    }
}

package LWP::Conn::FTP::Size;
use base 'LWP::Conn::FTP';

sub response
{
    my($self, $r, $code) = @_;
    my $skip_mdtm = *$self->{'lwp_noMDTM'};
    if ($r eq "2") {
	if ($self->message =~ /^\d+\s+(\d+)$/) {
	    *$self->{'lwp_res'}->content_length($1);
	}
    } elsif ($code eq "550") {
	# Unluckily, we get the same answer for a file that does not
	# exists and a file that happens to be a directory, so we must
	# continue (but we can skip MDTM)
	$skip_mdtm++
    } else {
	*$self->{'lwp_noSIZE'}++;
    }

    if ($skip_mdtm) {
	$self->state("Ready");
	$self->port();
    } else {
	my $file = *$self->{'lwp_file'};
	$self->send_cmd("MDTM $file" => "Mdtm");
    }
}


package LWP::Conn::FTP::Mdtm;
use base 'LWP::Conn::FTP';
use HTTP::Date qw(str2time);

sub response
{
    my($self, $r, $code) = @_;
    if ($r eq "2") {
	if ($self->message =~ /^\d+\s+(\d{8})(\d{6})?$/) {
	    my $t = str2time($2 ? "$1T$2" : $1);
	    *$self->{'lwp_res'}->last_modified($t);
	    # XXX  This is also the place to implement If-Modified-Since
	}
    } elsif ($code ne "550") {
	*$self->{'lwp_noMDTM'}++;
    }
    $self->state("Ready");
    $self->port();
}


package LWP::Conn::FTP::Dele;
use base 'LWP::Conn::FTP';

sub response
{
    my($self, $r, $code) = @_;
    $self->state("Ready");
    my $mess = $self->message;
    $mess =~ s/^\d+\s+//;
    chomp($mess);
    if ($r eq "2") {
	$self->give_response(204, $mess);
    } elsif ($code eq "550") {
	$self->give_response(404, $mess);
    } else {
	$self->give_response(400, $mess);
    }
}

package LWP::Conn::FTP::Port;
use base 'LWP::Conn::FTP';

sub response
{
    my($self, $r) = @_;
    if ($r eq "2") {
	my $cmd = *$self->{'lwp_meth'} eq "PUT" ? "STOR" : "RETR";
	my $file = *$self->{'lwp_file'};
	$self->send_cmd("$cmd $file" => "Trans");
    } else {
	$self->_error("PORT failed");
    }
}

package LWP::Conn::FTP::Trans;
use base 'LWP::Conn::FTP::Ready';

sub activate
{
    # ignore
}

sub response
{
    my($self, $r, $code) = @_;
    if ($r eq "1") {
	# info message only, we know that the response will succeed
	# and if method is "HEAD" we might want to send a ABRT at
	# this time...
	my $res = *$self->{'lwp_res'};
	if ($self->message =~ /\((\d+)\s+bytes\)/) {
	    # If it is already set, should we compare it with the
	    # previous value??
	    $res->content_length($1);
	}
	*$self->{'lwp_req'}->response_data("", $res);
	# XXX catch except
	$self->abort if *$self->{'lwp_meth'} eq "HEAD";
    } elsif ($r eq "2") {
	# we are done.  Must sync with closing of data connection
	$self->data_done($code);
    } elsif ($code eq "426") {  # transfer aborted
	*$self->{'lwp_res'}->header("Abort" => $self->message);
	$self->data_done($code);
    } elsif ($code eq "550") {  # no such file
	if (lc($self->message) =~ /or directory/) {
	    delete(*$self->{'lwp_data'})->close;
	    $self->state("Ready");
	    $self->give_response(404);
	} else {
	    # It might still be a directory, try to list it
	    my $file = *$self->{'lwp_file'};
	    $self->send_cmd("LIST $file" => "List");
	    my $res = *$self->{'lwp_res'};
	    $res->content_type("text/ftp-dir-listing");
	    $res->remove_header("Content-Encoding");
	}
    } else {
	$self->error("Trans");
    }
}

sub data
{
    my $self = shift;
    #return if *$self->{'lwp_meth'} eq "HEAD";

    eval {
	*$self->{'lwp_req'}->response_data($_[0], *$self->{'lwp_res'});
    };
    if ($@) {
	# Initiate ABRT
	$self->abort
    }
}

sub data_really_done
{
    my $self = shift;
    my $req = delete *$self->{'lwp_req'};
    my $res = delete *$self->{'lwp_res'};
    $req->response_done($res);

    # Start with next request
    $self->state("Ready");
    $self->activate;
}

sub data_done
{
    my($self, $code) = @_;
    if ($code && $code eq "426") {
	$self->data_really_done;
    } else {
	$self->state("TransWait");
    }
}

package LWP::Conn::FTP::TransWait;
use base 'LWP::Conn::FTP::Trans';

sub activate {}

sub data_done
{
    my $self = shift;
    $self->data_really_done;
}

sub response
{
    my $self = shift;
    my($r, $code) = @_;
    if ($code eq "225" || $code eq "226") {
	# ABOR command successful ignored
	$self->data_really_done;
	return;
    }
    $self->SUPER::response(@_);
}


package LWP::Conn::FTP::List;
use base 'LWP::Conn::FTP::Trans';

sub response
{
    my($self, $r, $code) = @_;
    if ($r eq "1") {
	# info message, ignore
	*$self->{'lwp_req'}->response_data("", *$self->{'lwp_res'});
	# XXX catch except
    } elsif ($r eq "2") {
	# we are done.  Must sync with data_done callback
	$self->data_done($self->message);
    } elsif ($code eq "550") {
	delete(*$self->{'lwp_data'})->close;
	$self->state("Ready");
	$self->give_response(404);
    } else {
	$self->error("LIST");
    }
}



package LWP::Conn::FTP::Cwd;
use base 'LWP::Conn::FTP';

sub cwd
{
    my $self = shift;
    my $dir = shift @{*$self->{'lwp_cwd'}};
    if ($dir) {
	if ($dir eq "..") {
	    $self->send_cmd("CDUP");
	} else {
	    $self->send_cmd("CWD $dir");
	}
    } else {
	$self->state("Ready");
	$self->cwd_done;
    }
}

sub response
{
    my($self, $r) = @_;
    if ($r eq "2") {
	$self->cwd;
    } else {
	$self->error("Can't CWD");
    }
}


package LWP::Conn::FTP::Data::Listen;
use base 'IO::Socket::INET';

use LWP::MainLoop qw(mainloop);

sub readable
{
    my $self = shift;
    if (my $data = $self->accept) {
	print "FTP DATA ACCEPT\n" if $LWP::Conn::FTP::DEBUG &&
	                             $LWP::Conn::FTP::DEBUG > 2;
	mainloop->readable($data);
	bless $data, "LWP::Conn::FTP::Data";
	if (my $w = *$self->{'lwp_write'}) {
	    *$data->{'lwp_write'} = $w;
	    *$data->{'lwp_wbuf'}  = '';
	    mainloop->writable($data);
	}
	my $ftp = *$self->{'lwp_ftp'};
	*$data->{'lwp_ftp'} = $ftp;
	*$ftp->{'lwp_data'} = $data;
    } else {
	*$self->{'lwp_ftp'}->_error("Can't accept");
    }
    mainloop->forget($self);
    $self->close;
}

sub close
{
    my $self = shift;
    mainloop->forget($self);
    $self->SUPER::close;
}

package LWP::Conn::FTP::Data;
use base 'LWP::Conn::FTP::Data::Listen';

use LWP::MainLoop qw(mainloop);

sub readable
{
    my $self = shift;
    my $buf = "";
    mainloop->activity(*$self->{'lwp_ftp'});
    my $n = sysread($self, $buf, 2048);
    if ($n) {
	print "FTP DATA READ $n bytes\n" if $LWP::Conn::FTP::DEBUG &&
	                                    $LWP::Conn::FTP::DEBUG > 2;
	*$self->{'lwp_ftp'}->data($buf);
    } else {
	if (defined $n) {
	    *$self->{'lwp_ftp'}->data_done();
	} else {
	    *$self->{'lwp_ftp'}->_error("Data connection error: $!");
	}
	$self->close;
    }
}

sub writable
{
    my $self = shift;
    #print "Writeable\n";
    mainloop->activity(*$self->{'lwp_ftp'});
    my $buf = \*$self->{'lwp_wbuf'};
    unless (defined $$buf and length $$buf) {
	my $w = *$self->{'lwp_write'};
	unless ($w) {
	    *$self->{'lwp_ftp'}->data_done();
	    $self->close;
	    return;
	}
	$w = $$w if ref($$w);
	if (ref($w) eq "CODE") {
	    $$buf = &$w();
	    unless (defined $$buf and length $$buf) {
		delete *$self->{'lwp_write'};
		return;
	    }
	} else {
	    $$buf = $$w;
	    delete *$self->{'lwp_write'};
	}
	return unless length $$buf;
    }
    my $len = length($$buf);
    $len = 2048 if $len > 2048;
    my $n = syswrite($self, $$buf, $len);
    if ($n) {
	print "FTP DATA WRITE $n bytes\n" if $LWP::Conn::FTP::DEBUG &&
	                                     $LWP::Conn::FTP::DEBUG > 2;
	substr($$buf, 0, $n) = '';
    } else {
	*$self->{'lwp_ftp'}->_error("Data connection error: $!");
	$self->close;
    }
}

1;

