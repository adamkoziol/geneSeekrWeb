package CSSstyle;

sub new {
	my ($class, @args) = @_;
	bless {}, $class;
}

sub style {
	 
	# A here-document allows you to create a string that spreads on multiple lines and preserves white spaces and new-lines.
	# A here document starts with two less-than characters << followed by an arbitrary string that becomes the designated end-mark of the here-document.

	my $style = <<"EOT";

	p {
		text-align:center
	}	
	h1 {
		text-align:center
	}		
	
	table { 
		margin-left: auto;
		margin-right: auto;
	}
	
	table td {
		text-align:right;
	}

	table td + td {
		text-align:left;
	}


EOT
# End of here document   

     return $style;
}
1;
