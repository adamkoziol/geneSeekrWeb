#!/usr/bin/perl -wT
use lib "/usr/lib/cgi-bin/geneSeekr/lib";
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
					-href=>"http://www.inspection.gc.ca"},"Canadian Food Inspection Agency<br>Agence canadienne d\'inspection des aliments"
				)
			),

			$cgi->td({-style=>"width:33%"},
				$cgi->a({
					-href=>"http://192.168.1.6/cgi-bin/geneSeekr/geneSeekr_welcome.cgi"},
					$cgi->img ( {
						-class=>'Banner',
						-src=>'/geneSeekr/images/cfia_maple_leaf.jpg',
						-alt=>'Canadian Food Inspection Agency/Agence canadienne d\'inspection des aliments'}
					)
				)
			),

			$cgi->td({-style=>"width:33%"},
				$cgi->a({
					-href=>"http://www.canada.gc.ca"},
					$cgi->img(  {
						-class=>'Canada',
						-src=>'/geneSeekr/images/wmms.svg',
						-alt=>'Canadian Food Inspection Agency/Agence canadienne d\'inspection des aliments'}
					)
				)
			)
		)
	);

	print $cgi->h1('GeneSeekr');

	# Print pertinent information regarding the tool
	print $cgi->p("Welcome to the CFIA GeneSeekr.<br> The GeneSeekr uses assembled contigs as input to determine the presence of certain markers
			associated with pathogenesis.");

	# Start the data collection form
	print $cgi->start_form(-method => 'POST',
                         -id => 'upload_form',
                         -name => 'upload_form',
                         -action => "/cgi-bin/geneSeekr/geneSeekr_results.cgi",
                         -enctype => 'multipart/form-data');

	# Construct the form
	print $cgi->table({-class=>'Normal'},
		$cgi->Tr($cgi->td(['Submitter', textfield(-name=>'submitterName')])),
		$cgi->Tr($cgi->td(['Analyst', textfield(-name=>'analyst')])),
		$cgi->Tr($cgi->td(['Organisation', textfield (-name=>'organisation')])),
		$cgi->Tr($cgi->td(['Please select one or more genomes to upload for processing', filefield({-multiple=>'true',-name=>'queryFiles'})])),
		$cgi->Tr($cgi->td([submit(-name=>'Submit'), reset]))

	);

	print $cgi->end_form();
}

