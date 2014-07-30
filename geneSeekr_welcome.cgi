#!/usr/bin/perl -wT
use lib "/usr/lib/cgi-bin/geneSeekr/lib/";
use CGI qw/:all/;
use CGI::Carp 'fatalsToBrowser';

####################

my $cgi = CGI->new();
print $cgi->header();
generateHeader();
display();
generateFooter();
####################

sub generateHeader {
	# Start HTML
	print $cgi->start_html(-title=>'CFIA ACIA GeneSeekr',
			 -style=> {
			 -src=>"/geneSeekr/CSS/geneSeekr.css",
			 }
			 );
}
####################
sub generateFooter {
	print $cgi->end_html();
}
####################
sub display {
	# Display the banner
	print $cgi->table({
			-class=>'Top'},
		$cgi->Tr(
			$cgi->td({-style=>"width:33%"}, ""),
			$cgi->td({-style=>"width:33%"}, $cgi->img ( {
					-class=>'Government',
					-src=>'/geneSeekr/images/sig-eng.svg',
					-alt=>'Government of Canada/Gouvernement du Canada'}))));

	print $cgi->table({
			-class=>'Normal'},
		$cgi->Tr(
			$cgi->td({-style=>"width:33%"},
				$cgi->a({
					-class=>'white',
					-style=>'font-size:120%',
					-href=>"http://www.inspection.gc.ca"},"Canadian Food Inspection Agency<br>Agence canadienne d\'inspection des aliments")),

			$cgi->td({-style=>"width:33%"},
				$cgi->img ( {
					-class=>'Banner',
					-src=>'/geneSeekr/images/cfia_maple_leaf.jpg',
					-alt=>'Canadian Food Inspection Agency/Agence canadienne d\'inspection des aliments'
			})),

			$cgi->td({-style=>"width:33%"},
				$cgi->a({
					-href=>"http://www.canada.gc.ca"},
					$cgi->img(  {
						-class=>'Canada',
						-src=>'/geneSeekr/images/wmms.svg',
						-alt=>'Canadian Food Inspection Agency/Agence canadienne d\'inspection des aliments'})
				)
			)
		));

	# h1 with larger than normal font size
	print $cgi->h1({
		-style=>'font-size:200%'},"Please select the appropriate tool for your needs");

	# makes pretty link buttons using the fancy button css class
	print $cgi->h1(a({
		-href=>"/cgi-bin/geneSeekr/geneSeekr_webTool.cgi",
		-class=>"fancyButton"}, "GeneSeekr"),

		$cgi->a({
			-href=>"/cgi-bin/geneSeekr/geneSippr_webTool.cgi",
			-class=>"fancyButton"}, "GeneSippr"));




}

