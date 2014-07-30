#!/usr/bin/perl -w

use Cwd;
use Time::Piece;
use threads;
use Bio::SearchIO;
use Data::Dumper qw(Dumper);
use CGI::Carp 'fatalsToBrowser';
use CGI qw/:standard *table/;
use lib "/usr/lib/cgi-bin/geneSeekr/lib/geneSeekrModules";
use CGI qw/:all/;
use HTML;
use CGI::Pretty qw( :html3 );
use File::Basename;
use rawReadSipping;
use CGI::Carp 'fatalsToBrowser';

# Calls the upload module in /usr/lib/cgi-bin/lib/Upload/upload.pm
use upload;
# For some reason, I still need to make this variable in order to get the upload module to work
my $query = CGI->new();
my $path = getcwd;
########################################################
#GeneSeekr code

# Initialise variables

my $geneSipping = rawReadSipping->new();

my %geneSippr = $geneSipping->sippr();
my %targetList = $geneSipping->targets();
my $dateTime = $geneSipping->dateTime();

# Get the data for naming the output file
my $time =  localtime;
my $date = $time->ymd(".");

my @order = qw (O157 H7 O VT1 VT2 h eae Z2099);
# Custom hash ordering courtesy of:
# http://stackoverflow.com/questions/8171528/in-perl-how-can-i-sort-hash-keys-using-a-custom-ordering
my %order_map = map { $order[$_] => $_ } 0 .. $#order;
my $pat = join '|', @order;

open (OUTPUT, ">", "/var/www/geneSeekr/reports/GeneSippr_results_$dateTime.xls") or die $!;
open (OUTPUT_QUALITY, ">", "/var/www/geneSeekr/reports/GeneSippr_Quality_results_$dateTime.xls") or die $!;
open (HTML, ">", "/var/www/geneSeekr/reports/GeneSippr_results_$dateTime.html") or die $!;
open (HTML_QUALITY, ">", "/var/www/geneSeekr/reports/GeneSippr_Quality_results_$dateTime.html") or die $!;

# Prepare hashes with the appropriate data - either gene target results or quality target results
foreach my $targetGene (sort keys %targetList) {
	# The pathogen genes are in CHAS.fa
	if ($targetGene eq 'CHAS') {
		# Prep the hash with the data for the header data for the results table
		foreach my $gene (sort keys %{ $targetList{$targetGene} }) {
			$chasList{$targetGene}{$gene} = $targetList{$targetGene}{$gene};
		}
		# Get the results ready to parse
		foreach my $strain (sort keys %{ $geneSippr{$targetGene} }) {
			# Get the presence/absence working
			# If the gene from the total list of genes ($listGene is present, then make a hash with a "+" otherwise a "-"
			foreach my $listGene (sort keys %{ $targetList{$targetGene} }) {
				$totalCHAS =  scalar keys %{ $targetList{$targetGene} };
				if (exists $geneSippr{$targetGene}{$strain}{$listGene}) {
					$chasFinalResults{$targetGene}{$strain}{$listGene} = "+";
				} else {
					$chasFinalResults{$targetGene}{$strain}{$listGene} = "-";
				}
			}
		}
	} elsif ($targetGene eq 'qualityGenes') {
		# Prep the hash with the data for the header data for the quality results table
		foreach my $gene (sort keys %{ $targetList{$targetGene} }) {
			$qualityList{$targetGene}{$gene} = $targetList{$targetGene}{$gene};
		}
		# Get the quality results ready to parse
		foreach my $strain (sort keys %{ $geneSippr{$targetGene} }) {
			# Get the presence/absence working
			# If the gene from the total list of genes ($listGene is present, then make a hash with a "+" otherwise a "-"
			foreach my $listGene (sort keys %{ $targetList{$targetGene} }) {
				$totalQuality =  scalar keys %{ $targetList{$targetGene} };
				if (exists $geneSippr{$targetGene}{$strain}{$listGene}) {
					$qualityFinalResults{$targetGene}{$strain}{$listGene} = "+";
				} else {
					$qualityFinalResults{$targetGene}{$strain}{$listGene} = "-";
				}
			}
		}
	}
}


# Print HTML Results table
print HTML $query->start_html(-title=>'CFIA ACIA GeneSippr Results',
			 -style=> {
			 -src=>"/geneSeekr/CSS/geneSeekr.css",
			 -code=>"body{background-image:none}"
			}
			 );
# Print the header
print HTML $query->table({-class=>'OutputLeft'},
	map {
		my $targetGene = $_;
		$query->Tr($query->th('Strain'),
		map {
			my $gene = $_;
			$query->th($gene),
		} sort { my ($x, $y) = map /^($pat)/, $a, $b; $order_map{$x} <=> $order_map{$y}} keys %{ $chasList{$targetGene} }
		),

		map {
			my $strain = $_;
			$query->Tr({-align=>'center'},$query->td($strain),
			#$chasFinalResults{$targetGene}{$strain}{$listGene} = "+";
			map {
				my $gene =$_;
				$query->td($chasFinalResults{$targetGene}{$strain}{$gene})
			} sort { my ($x, $y) = map /^($pat)/, $a, $b; $order_map{$x} <=> $order_map{$y}} keys %{ $chasFinalResults{$targetGene}{$strain} }
			)
		} sort keys %{ $chasFinalResults{$targetGene} }

	} sort keys %chasList

);
close HTML;
# Print HTML Quality Results table
print HTML_QUALITY $query->start_html(-title=>'CFIA ACIA GeneSippr Quality Results',
			 -style=> {
			 -src=>"/geneSeekr/CSS/geneSeekr.css",
			 -code=>"body{background-image:none}"
			}
			 );
# Print the header
print HTML_QUALITY $query->table({-class=>'OutputLeft'},
	map {
		my $targetGene = $_;
		$query->Tr($query->th('Strain'),
		map {
			my $gene = $_;
			$query->th($gene),
		} sort keys %{ $qualityList{$targetGene} }
		),

		map {
			my $strain = $_;
			$query->Tr({-align=>'center'},
			$query->td($strain),
			#$chasFinalResults{$targetGene}{$strain}{$listGene} = "+";
			map {
				my $gene =$_;
				$query->td($qualityFinalResults{$targetGene}{$strain}{$gene})
			} sort keys %{ $qualityFinalResults{$targetGene}{$strain} }
			)
		} sort keys %{ $qualityFinalResults{$targetGene} }

	} sort keys %qualityList

);
close HTML_QUALITY;

# Prepare the .xls outputs

# Results
print OUTPUT "Strain\t";

# Print the header
# %chasList: $chasList{$targetGene}{$gene}
foreach my $targetGene (sort keys %chasList) {
	foreach my $gene (sort { my ($x, $y) = map /^($pat)/, $a, $b; $order_map{$x} <=> $order_map{$y}} keys %{ $chasList{$targetGene} }) {
		print OUTPUT "$gene\t";
	}
}

# Print the results
#$chasFinalResults{$targetGene}{$strain}{$listGene} = "+";
foreach my $targetGene (sort keys %chasFinalResults) {
	foreach my $strain (sort keys %{ $chasFinalResults{$targetGene} } ) {
		print OUTPUT "\n$strain\t";
		foreach my $listGene (sort { my ($x, $y) = map /^($pat)/, $a, $b; $order_map{$x} <=> $order_map{$y}} keys %{ $chasFinalResults{$targetGene}{$strain} } ) {
			print OUTPUT "$chasFinalResults{$targetGene}{$strain}{$listGene}\t";
		}
	}
}

# Quality Results
print OUTPUT_QUALITY "Strain\t";

# Print the header
# %qualityList: $chasList{$targetGene}{$gene}
foreach my $targetGene (sort keys %qualityList) {
	foreach my $gene (sort { my ($x, $y) = map /^($pat)/, $a, $b; $order_map{$x} <=> $order_map{$y}} keys %{ $qualityList{$targetGene} }) {
		print OUTPUT_QUALITY "$gene\t";
	}
}

close OUTPUT;

# Print the results
#$qualityFinalResults{$targetGene}{$strain}{$listGene} = "+";
foreach my $targetGene (sort keys %qualityFinalResults) {
	foreach my $strain (sort keys %{ $qualityFinalResults{$targetGene} } ) {
		print OUTPUT_QUALITY "\n$strain\t";
		foreach my $listGene (sort { my ($x, $y) = map /^($pat)/, $a, $b; $order_map{$x} <=> $order_map{$y}} keys %{ $qualityFinalResults{$targetGene}{$strain} } ) {
			$observedQuality = scalar(keys %{ $qualityFinalResults{$targetGene}{$strain} });
			print OUTPUT_QUALITY "$qualityFinalResults{$targetGene}{$strain}{$listGene}\t";
		}
	}
}

close OUTPUT_QUALITY;

# Prepare outputs for printing
foreach my $targetGene (sort keys %chasFinalResults) {
	foreach my $strain (sort keys %{ $chasFinalResults{$targetGene} } ) {
		foreach my $listGene (sort { my ($x, $y) = map /^($pat)/, $a, $b; $order_map{$x} <=> $order_map{$y}} keys %{ $chasFinalResults{$targetGene}{$strain} } ) {

			if ($chasFinalResults{$targetGene}{$strain}{$listGene} eq "-") {
			} else {
				push (@pathotype, $listGene);
			}
		}
		if ($observedQuality >= ($totalQuality)) {
			$passFail = "Pass ($observedQuality/$totalQuality)";
		} else {
			$passFail = "Fail ($observedQuality/$totalQuality)";
		}
		# Load the output hash
	$commaFormat = commas(@pathotype);
	undef @pathotype;
	$output{$strain}{$commaFormat} = $passFail;
	}

}

# Clean up the temporary files
chdir ("$path/tmp");
unlink glob ("*.blast");

chdir ("$path/uploads");
unlink glob ("*.fa*");

chdir ("$path/SipprResults/reports");
unlink glob ("*.fa");

chdir ("$path/SipprResults/tmp");
unlink glob ("*");

chdir ("$path");
####################################################################################

### HTML VARS

my $localhost="192.168.1.6";
my $script = script_name();
my $localhost_script = $localhost . $script;

# Parameters passed from the geneSeekr_webTool script
my $sampleNumber = $query->param("sampleNumber");
my $submitterName = $query->param("submitterName");
my $analyst = $query->param("analyst");
my $organisation = $query->param("organisation");



################### START HTML PAGE
my $cgi = CGI->new();
print $cgi->header();

generateHeader();
jTables();
display();
generateFooter();
exit;


sub generateHeader {
	print $cgi->start_html(-title=>'CFIA ACIA GeneSeekr Results',
			 -style=> {
			 -src=>"/geneSeekr/CSS/geneSeekr.css",
			 }
			 );
}

sub generateFooter {
	print $cgi->hr();
	print $cgi->p('Report Generated with GeneSippr v0.2');
	print $cgi->end_form();
	print $cgi->end_html();
}

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

	print $cgi->h1('GeneSippr');

	print $cgi->table({-class=>'Boxed'},
		$cgi->Tr($cgi->td(['Date', $date])),
		$cgi->Tr($cgi->td()),
		$cgi->Tr($cgi->td(['Submitter', $submitterName])),
		$cgi->Tr($cgi->td()),
		$cgi->Tr($cgi->td(['Analyst', $analyst])),
		$cgi->Tr($cgi->td()),
		$cgi->Tr($cgi->td(['Organisation', $organisation])),
	);
	# <a class="various fancybox.iframe" href="http://192.168.1.6/geneSeekr/images/quality.html">table</a>
	my $pathotypeHTML = $cgi->a({
				-class=>'fancybox fancybox.iframe',
				-href=>"http://$localhost/geneSeekr/reports/GeneSippr_results_$dateTime.html"}, '(View)');
	my $pathotypeXLS = $cgi->a({-href=>"http://$localhost/geneSeekr/reports/GeneSippr_results_$dateTime.xls"}, '(Download)');
	my $qualityHTML = $cgi->a({
				-class=>'resized fancybox.iframe',
				-href=>"http://$localhost/geneSeekr/reports/GeneSippr_Quality_results_$dateTime.html"}, '(View)');

	#my $qualityHTML = $cgi->a({-href=>"http://$localhost/geneSeekr/reports/Quality_results_$dateTime.html"}, '(View)');
	my $qualityXLS = $cgi->a({-href=>"http://$localhost/geneSeekr/reports/GeneSippr_Quality_results_$dateTime.xls"}, '(Download)');

	print $cgi->table({-class=>'Output'},
		$cgi->Tr($cgi->th(['Strain', "Pathotype $pathotypeHTML $pathotypeXLS", "Quality Pass/Fail $qualityHTML $qualityXLS"])),
		# Same as above for the creation of the HTML table
		map {
			# Instead of foreach my $strain (sort keys %strain_data)
			my $strain = $_;
			# Start the table
			$cgi->Tr(
				# Strain name
				$cgi->td($strain),
				map {
					# Results: $_ is the comma-separated list of gene matches, $output{$strain}{$_} is the pass/fail results
					$cgi->td([$_, $output{$strain}{$_}]),
				} keys %{ $output{$strain} }
			)
		} keys %output
	);

}

#################################################################
sub commas {
	my $sepchar = grep(/,/ => @_) ? ";" : ",";
	(@_ == 0) ? ''			:
	(@_ == 1) ? $_[0]		:
	(@_ == 2) ? join(", ", @_)	:
		    join("$sepchar ", @_[0 .. ($#_-1)], "$_[-1]");


}

################################################################
sub jTables {

print qq(
<!-- Add jQuery library -->
<script type="text/javascript" src="http://code.jquery.com/jquery-latest.min.js"></script>

<!-- Add mousewheel plugin (this is optional) -->
<!--<script type="text/javascript" src="http://$localhost/geneSeekr/fancybox/lib/jquery.mousewheel-3.0.6.pack.js"></script>

<!-- Add fancyBox -->
<link rel="stylesheet" href="http://$localhost/geneSeekr/fancybox/source/jquery.fancybox.css?v=2.1.5" type="text/css" media="screen" />
<script type="text/javascript" src="http://$localhost/geneSeekr/fancybox/source/jquery.fancybox.pack.js?v=2.1.5"></script>

<!-- Optionally add helpers - button, thumbnail and/or media -->
<link rel="stylesheet" href="http://$localhost/geneSeekr/fancybox/source/helpers/jquery.fancybox-buttons.css?v=1.0.5" type="text/css" media="screen" />
<script type="text/javascript" src="http://$localhost/geneSeekr/fancybox/source/helpers/jquery.fancybox-buttons.js?v=1.0.5"></script>
<script type="text/javascript" src="http://$localhost/geneSeekr/fancybox/source/helpers/jquery.fancybox-media.js?v=1.0.6"></script>

<link rel="stylesheet" href="lightbox/fancybox/source/helpers/jquery.fancybox-thumbs.css?v=1.0.7" type="text/css" media="screen" />
<script type="text/javascript" src="http://$localhost/geneSeekr/fancybox/source/helpers/jquery.fancybox-thumbs.js?v=1.0.7"></script>


<script type="text/javascript">
\$(document).ready(function() {
	\$(".fancybox").fancybox({
		maxWidth	: '800',
		openEffect	: 'elastic',
  		closeEffect	: 'elastic'
	});
});
</script>

<script type="text/javascript">
\$(document).ready(function() {
	\$(".various").fancybox({
		fitToView	: false,
		autoSize	: false,
		autoWidth	: false,
		closeClick	: false,
		openEffect	: 'elastic',
  		closeEffect	: 'elastic'
	});
});
</script>

<script type="text/javascript">
\$(document).ready(function() {
 \$(".resized").fancybox({
  openEffect : 'elastic',
  closeEffect : 'elastic',
  fitToView: false,
  autoSize	: false,
  maxWidth	: '825',
  nextSpeed: 0, //important
  prevSpeed: 0, //important
  beforeShow: function(){
  // added 50px to avoid scrollbars inside fancybox
   this.width = (\$('.fancybox-iframe').contents().find('html').width())+50;
   this.height = (\$('.fancybox-iframe').contents().find('html').height())+50;
  }
 }); // fancybox
}); // ready
</script>


);
}





