=head1 NAME
   DATA - A module for data retrieval (from SAMdb) and processing

=head1 SYNOPSIS
   use DATA
   #include sub name here

=head1 DESCRIPTION

=head1 EXAMPLES

=head1 NOTES

=head1 AUTHOR
   Rene Warren April 2003
=cut


package DATA;

use strict;

#use SQLdb;

use CGI qw/:all/;
#use Number::Format;
    #use Cache::FileCache;
#use Date::Manip;
    #use GD::Graph::mixed;
    #use GD;
#use Statistics::Descriptive;
    #use SequenceAnalysis;
    #use SDB::DBIO;
use Data::Dumper;
#use Mail::Sender;


################### File #############################

#----------------------------------
####Obtain htdocs, cgi-bin and script information
sub getScriptLocation{

   my $scriptname=shift;
   my $config_file=shift;

   my $cgipath=$1 if ($scriptname =~ /(.*)\/.*\.pl/);
   open (OUT, "$config_file") or die "Can't open $config_file";
   my $htdocpath=<OUT>; #reads the first line of the file
   chomp($htdocpath);
   close OUT;

   return $cgipath, $htdocpath;

}

#----------------------------------
####Get user info
sub getDBInfo{

   my $config_file=shift;

   my $dbinfo;

   open (OUT, "$config_file") or die "Can't open $config_file";
   my $line=<OUT>;
   ($dbinfo->{'database'},$dbinfo->{'host'},$dbinfo->{'clef'}) = split(':', $line);

   return $dbinfo;
}


#----------------------------------
sub checkDatabaseConnection{

   my $userinfo = shift;

   $userinfo->{'pass'} = -1;

   if ($userinfo->{'username'} ne "na" && $userinfo->{'username'} ne "" ){
      my $dbh;
      eval{
         ####Initialize the database
         $dbh=SQLdb::Initialize($userinfo->{'password'}, $userinfo->{'username'}, $userinfo->{'database'}, $userinfo->{'host'});
         SQLdb::Disconnect($dbh);
      };

      if($@){
         $userinfo->{'password'}=$userinfo->{'username'}='';
         $userinfo->{'pass'}=0;
         #print "$@";
      }else{
         $userinfo->{'pass'}=1;
      }
   }

   return $userinfo;
}

#-------------------------------------
sub insertRecord{

   my ($userinfo,$fields,$values,$table) = @_;

   my $message = "";
   my @record;
   ####Initialize Database Connection

   eval{
      my $dbh=SQLdb::Initialize($userinfo->{'password'}, $userinfo->{'username'}, $userinfo->{'database'}, $userinfo->{'host'});
      ####Add records 
      SQLdb::InsertRecord($dbh, $table, $fields, $values);
      SQLdb::Disconnect($dbh);

   };

   if($@){
      $message = "Something went wrong while adding record to table $table: $@";
   }else{
      eval{
         my $dbh=SQLdb::Initialize($userinfo->{'password'}, $userinfo->{'username'}, $userinfo->{'database'}, $userinfo->{'host'});
         my $select = "select id, description from $table order by id DESC limit 1";
         my $rec = SQLdb::ExecuteUnique($dbh,$select);
         @record = @$rec;
         SQLdb::Disconnect($dbh);
      };
      if($@){
         $message = "Something went wrong while reading record from table $table: $@";
      }else{
         $message = "Successfully inserted record (id=$record[0], description=$record[1]) in table $table.\n"; 
      }
   }
   return $message;
}


#-------------------------------------
sub updateRecord{

   my ($userinfo,$fields,$values,$table,$record_id) = @_;

   my $message = "";
   my @record;
   ####Initialize Database Connection

   eval{
      my $dbh=SQLdb::Initialize($userinfo->{'password'}, $userinfo->{'username'}, $userinfo->{'database'}, $userinfo->{'host'});
      ####Add records
      my @condition = ("id = $record_id");
      SQLdb::UpdateRecord($dbh, $table, $fields, $values, \@condition);
      SQLdb::Disconnect($dbh);

   };

   if($@){
      $message = "Something went wrong while updating record $record_id to table $table: $@";
   }else{
      $message = "Successfully updated record (id=$record_id) from table $table.\n";
   }
   return $message;
}


#-------------------------------------
sub getFields{

   my ($login,$table) = @_;

   my $dbh=SQLdb::Initialize($login->{'password'}, $login->{'username'}, $login->{'database'}, $login->{'host'});
   my $select = "describe $table";
   my $tmp_gf_list=SQLdb::ExecuteMany($dbh,$select);

   my @list=@$tmp_gf_list;
   my @gf_list;

   foreach my $reference (@list){
      my @record=@$reference;
      my @temp_gf=($record[0], $record[1], $record[2], $record[3]);
      push @gf_list, \@temp_gf;
   }
   return \@gf_list;
}


#-------------------------------------
sub getAllTableNames{

   my $login = shift;

   my $dbh=SQLdb::Initialize($login->{'password'}, $login->{'username'}, $login->{'database'}, $login->{'host'});
   my $select = "show tables";
   my $tmp_gf_list=SQLdb::ExecuteMany($dbh,$select);

   my @list=@$tmp_gf_list;
   my @gf_list;

   foreach my $reference (@list){
      my @record=@$reference;
      my @temp_gf=($record[0], $record[1], $record[2], $record[3]);
      push @gf_list, \@temp_gf;
   }
   return \@gf_list;
}


#-------------------------------------
sub getIdName{###

   my ($login,$table) = @_;

   my $dbh=SQLdb::Initialize($login->{'password'}, $login->{'username'}, $login->{'database'}, $login->{'host'});
   my $select = "select id,description,date from $table order by id DESC";
   my $tmp_gf_list=SQLdb::ExecuteMany($dbh,$select);

   my @list=@$tmp_gf_list;
   my @gf_list;

   foreach my $reference (@list){
      my @record=@$reference;
      my @temp_gf=($record[0], $record[1], $record[2], $record[3]);
      #print "$record[0], $record[1]<br>";
      push @gf_list, \@temp_gf;
   }
   return \@gf_list;
}


#-------------------------------------
sub getAll{

   my ($login,$table,$field_name,$keyword) = @_;

   my $dbh=SQLdb::Initialize($login->{'password'}, $login->{'username'}, $login->{'database'}, $login->{'host'});
   my $select = "select * from $table where $field_name like '\%$keyword\%' order by id DESC";
   my $list=SQLdb::ExecuteMany($dbh,$select);

   return $list,$select;
}

#-------------------------------------
sub getAllDate{

   my ($login,$table,$field_name,$startdate,$enddate) = @_;

   my $dbh=SQLdb::Initialize($login->{'password'}, $login->{'username'}, $login->{'database'}, $login->{'host'});
   my $select = "select * from $table where $field_name between '$startdate' and '$enddate' order by id DESC";
   my $list=SQLdb::ExecuteMany($dbh,$select);

   return $list,$select;
}


#-------------------------------------
sub executeUserQuery{

   my ($login,$sql) = @_;

   my $list;

   eval{
      my $dbh=SQLdb::Initialize($login->{'password'}, $login->{'username'}, $login->{'database'}, $login->{'host'});
      $list=SQLdb::ExecuteMany($dbh,$sql);
   };

   return $list,$@;
}

#-------------------------------------
sub getSingleRecord{

   my ($login,$table,$record_id) = @_;

   my $dbh=SQLdb::Initialize($login->{'password'}, $login->{'username'}, $login->{'database'}, $login->{'host'});
   my $select = "select * from $table where id=$record_id";
   my $list=SQLdb::ExecuteUnique($dbh,$select);

   return $list;
}

1;
