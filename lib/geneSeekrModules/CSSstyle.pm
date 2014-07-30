package CSSstyle;
use Cwd;

sub new {
	my ($class, @args) = @_;
	bless {}, $class;
}

sub style {
	 
	# A here-document allows you to create a string that spreads on multiple lines and preserves white spaces and new-lines.
	# A here document starts with two less-than characters << followed by an arbitrary string that becomes the designated end-mark of the here-document.

	#table.Output Tr + Tr {background:  #F2F2F2;}

	my $style = <<"EOT";
	body {
		background-image:url("/images/geneSeekr/background.jpg");
		background-repeat:repeat-x;
		background-position:center top+9px;
		
		font-family:"Trebuchet MS", Arial, Helvetica, sans-serif;
	}

	img.Banner {
		display: block;
		margin-left: auto;
		margin-right: auto;
		margin-top:0px
	}

	table.Banner {
		margin-top:0px
	}

	a.white:visited, a.white:link  {
		 color:#FFFFFF;     
	}
	
	p {
		text-align:center;
	}
	
	h2 {
		position:absolute;
		top:100px;
		left:1000px:
		color:#ffffff;
	}

	h1 {
		text-align:center;
		color:#ffffff;
	}		
	
	table {
		border-collapse:collapse;
		margin-left: auto;
		margin-right: auto;
	}	

	table.Normal td {
		text-align:right;
	}

	table.Normal td + td {
		text-align:left;
	}

	table.Output { 
		font-family:"Trebuchet MS", Arial, Helvetica, sans-serif;
		border-collapse:collapse;
		border-bottom:2px solid #000000;
		background-color:#F2F2F2;
	}
		
	table.Output td, th {
		font-size:1em;
		padding:3px 7px 2px 7px;
	}	

	table.Output th {
				text-align:left;
		padding-top:5px;
		padding-bottom:4px;
		background-color:#ffffff;
		color:#000000;
		border-bottom:2px solid #000000;
	}	

	table.Output tr:nth-child(odd) {
		background: #FFF
	}

	table.Boxed td {
		text-align:right;
		padding-left:3px;
		padding-right:3px;
	}	

	table.Boxed td + td {
		border:1px solid #000000;
		padding-left:3px;
		padding-right:3px;
		text-align:left;
	}
	







EOT
# End of here document   

     return $style;
}
1;
