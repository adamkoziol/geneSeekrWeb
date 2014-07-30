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
#use HTML;
use CGI::Pretty qw( :html3 );
use File::Basename;
use qualityTest;
use CGI::Carp 'fatalsToBrowser';

# Calls the upload module in /usr/lib/cgi-bin/geneSeekrModules/lib/Upload/upload.pm
use upload;
# For some reason, I still need to make this variable in order to get the upload module to work
my $query = CGI->new();

########################################################
#GeneSeekr code

# Initialise variables
my (@threads_blast, @threads_formatdb, @queryGenes, @sequenceFiles, @pathotype, $passFail, $commas);
my (%strain_data, %output);

my $path = getcwd;

# Determine the number of threads present in the system
my @cpus = `awk '/^processor/ { N++} END { print N }' /proc/cpuinfo`;
chomp @cpus;

# Print a welcome message
#print "Welcome to the CFIA GeneSeekr.\n";
# The files must be in the "sequences" subfolder. This subfolder must only have sequences that you wish to examine, or the program won't be able to find them
#chdir ("$path/sequences");
chdir ("$path/uploads");

@sequenceFiles = glob("*.fa*");

chdir ("$path/query_genes");
@queryGenes = glob("*.fa");

# Multi-threaded approach to format the database
while (scalar(@threads_formatdb) < @cpus) {
	# Loop through each file to be subtyped
	foreach (@queryGenes) {
		# Make a new thread using the formatdb subroutine - pass appropriate values to subroutine
		my $t = threads->new(\&formatdb, $_);
		# Output data to @threads. Right now, all this does is increase the size for the scalar(@threads) portion of the while loop
		push(@threads_formatdb,$t);
	}
}

# This loop ensures that each thread is complete before terminating
foreach (@threads_formatdb) {
	# The join command is responsible for ensuring that all threads are complete
	my $num = $_->join;
}
#print "Identifying markers.\n";


# Using multi-threaded approach
# This while loop should ensure that the limit of the number of threads is the number of cpus
while (scalar(@threads_blast) < @cpus) {
	# Loop through each file to be subtyped
	foreach my $gene (@queryGenes) {
			foreach my $sequence (@sequenceFiles) {
			# Make a new thread using the blast subroutine - pass appropriate values to subroutine
			my $r = threads->new(\&blast, $path, $gene, $sequence);
			# Output data to @threads. Right now, all this does is increase the size for the scalar(@threads) portion of the while loop
			push(@threads_blast,$r);
		}
	}
}

# This loop ensures that each thread is complete before terminating
foreach (@threads_blast) {
	my $num = $_->join;
    # As the values returned from the blast subroutine are an array of hashes, $num must be treated as such - @$num
    foreach my $blast_return (@$num) {
    	# $a is the hash %results pushed to @scheme - must treat it as a hash in order to extract values
    	while (my ($blast_strain, $blast_allele) = each %$blast_return) {
    		# Reformat the data back into a hash - $strain_data{"strain"}{"gene"} = "allele"
    		$strain_data{$$num[0]}{$blast_strain} = $blast_allele;
    	}
    }
}

chdir ("$path");
my $qualityResults = qualityTest->new();

my %quality = $qualityResults->qualityChecker();
my $dateTime = $qualityResults->dateTime();

# Custom hash ordering courtesy of:
# http://stackoverflow.com/questions/8171528/in-perl-how-can-i-sort-hash-keys-using-a-custom-ordering
my @order = qw (O H7 VT1 VT2 eae Z2099 aggR bfpA hylA ipaH elt est);
my %order_map = map { $order[$_] => $_ } 0 .. $#order;
my $pat = join '|', @order;

# Get the data for naming the output file
my $time =  localtime;
my $date = $time->ymd(".");
my $hms = $time->hms(".");
open (OUTPUT, ">", "/var/www/geneSeekr/reports/GeneSeekr_results_$dateTime.xls") or die $!;
open (HTML, ">", "/var/www/geneSeekr/reports/GeneSeekr_results_$dateTime.html") or die $!;

print OUTPUT "Strain\tO-Antigen\tH7\tVT1\tVT2\teae\tZ2099\taggR\tbfpA\thylA\tipaH\telt\test\tQuality Pass/Fail";

foreach my $strain (sort keys %strain_data) {
	#  { $strain_data{$strain}{$a} cmp $strain_data{$strain}{$b}}
	print OUTPUT "\n$strain\t";
	foreach my $gene (sort { my ($x, $y) = map /^($pat)/, $a, $b; $order_map{$x} <=> $order_map{$y}} keys %{ $strain_data{$strain} }) { # see URL above for some idea what's going on
	#foreach my $gene (sort keys %{ $strain_data{$strain} }) {
		print OUTPUT "$strain_data{$strain}{$gene}\t";
	}
	while (my ($hits, $total) = each (%{ $quality{$strain} }) ) {
		#print "$strain has $hits out of $total\n";
		if ($hits >= ($total - 3)) {
			print OUTPUT "Pass ($hits/$total)\t";
		} else {
			print OUTPUT "Fail ($hits/$total)\t";
		}
	}
}
print OUTPUT "\n";

# Print HTML Results table
print HTML $query->start_html(-title=>'CFIA ACIA GeneSeekr Results',
			 -style=> {
			 -src=>"/geneSeekr/CSS/geneSeekr.css",
			 -code=>"body{background-image:none}"
			}
			 );
print HTML $query->table({-class=>'OutputLeft'},
	$query->Tr($query->th(['Strain', 'O-Antigen', 'H7', 'VT1', 'VT2', 'eae', 'Z2099', 'aggR', 'bfpA', 'hylA', 'ipaH', 'elt', 'est'])),
	# As you cannot use if, for, foreach, etc. loops in a CGI table, map must be used instead
	# The map function of Perl provides a simple way to transform a list of values to another list of values. Usually this is a one-to-one transformation
	# but in general the resulting list can be also shorter or longer than the original list.
	map {
		# Instead of foreach my $strain (sort keys %strain_data)
		my $strain = $_;
		# Start the table
		$query->Tr({-align=>'center'},
			# Strain name
			$query->td($strain),
			map {
				# Results
				$query->td($strain_data{$strain}{$_}),
				#$query->td("+"),
		} sort { my ($x, $y) = map /^($pat)/, $a, $b; $order_map{$x} <=> $order_map{$y}} keys %{ $strain_data{$strain} }
		)
	} sort keys %strain_data
	);

print HTML $query->end_html();

# Prepare the output for printing later
foreach my $strain (sort keys %strain_data) {
	foreach my $gene (sort { my ($x, $y) = map /^($pat)/, $a, $b; $order_map{$x} <=> $order_map{$y}} keys %{ $strain_data{$strain} }) {
		if ($strain_data{$strain}{$gene} eq "-") {
		} else {
			push (@pathotype, $strain_data{$strain}{$gene});

		}
	}

	while (my ($hits, $total) = each  (%{ $quality{$strain} }) ) {
		#print "$strain has $hits out of $total\n";
		if ($hits >= ($total - 3)) {
			$passFail = "Pass ($hits/$total)";
		} else {
			$passFail = "Fail ($hits/$total)";
		}
	# Load the output hash
	}
	$commaFormat = commas(@pathotype);
	undef @pathotype;
	$output{$strain}{$commaFormat} = $passFail;
}

# Clean up the temporary files
chdir ("$path/tmp");
unlink glob ("*.blast");

#chdir ("$path/uploads");
#unlink glob ("*.fa*");

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

sub generateHeader {
	print $cgi->start_html(-title=>'CFIA ACIA GeneSeekr Results',
			 -style=> {
			 -src=>"/geneSeekr/CSS/geneSeekr.css",
			 }
			 );
}

sub generateFooter {
	print $cgi->hr();
	print $cgi->p('Report Generated with GeneSeekr v0.2');
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

	print $cgi->h1('GeneSeekr');

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
				-href=>"http://$localhost/geneSeekr/reports/GeneSeekr_results_$dateTime.html"}, '(View)');
	my $pathotypeXLS = $cgi->a({-href=>"http://$localhost/geneSeekr/reports/GeneSeekr_results_$dateTime.xls"}, '(Download)');
	my $qualityHTML = $cgi->a({
				-class=>'resized fancybox.iframe',
				-href=>"http://$localhost/geneSeekr/reports/Quality_results_$dateTime.html"}, '(View)');

	#my $qualityHTML = $cgi->a({-href=>"http://$localhost/geneSeekr/reports/Quality_results_$dateTime.html"}, '(View)');
	my $qualityXLS = $cgi->a({-href=>"http://$localhost/geneSeekr/reports/Quality_results_$dateTime.xls"}, '(Download)');

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

generateHeader();
jTables();
display();
generateFooter();
exit;

#################################
sub formatdb {
	# Gets the data passed to the subroutine - shift returns the first value from an array
	my $a = shift;
	# Unless the database files have already been processed...
	unless(-e("$_.nhr")) {
		# Call formatdb
		system("formatdb -i $a -o T -p F");
	}
}

##################################
sub blast {
	my ($path, $gene, $sequence) = @_;
	my ($file_name, %results, @scheme, $type, $hit_id, $hit_length, $hit_identical, $percent_identity);
	# Perform blastn search against database
	($gene_name = $gene) =~ s/.fa.*//g;
	($file_name = $sequence) =~ s/.fa.*//g;
	#print "Comparing $file_name against $gene_name.\n";
	#print ".";
	# -task dc-megablast -lcase_masking false -soft_masking false
	system("blastn -query $path/uploads/$sequence -db $path/query_genes/$gene -word_size 15 -outfmt 5 -max_target_seqs 1 -evalue 1e-10 -out $sequence.$gene.blast");
	#initialize the bioperl module SearchIO to read the input file. -format is #ed out as SearchIO can (usually) detect the format
	#
	my $in = new Bio::SearchIO (-format => 'blastxml', -file => "$sequence.$gene.blast");
	#while there are more results, keep moving on to the next result
	while ( my $result = $in->next_result ) {
		#while there are more hits, keep moving on to the next hit
		while ( my $hit = $result->next_hit ) {
			#while there are more HSPs, keep moving on to the next HSP
			while ( my $hsp = $hit->next_hsp ) {
				#if the percent identity of the hsp is exactly 100, then proceed:
				# The length of the hsp has to be full length - the length of the hit
				if ( $hit->length == $hsp->num_identical) {
					#the description, bit score, evalue, and percent identity of the results in the blast file
						($type = $hit->accession) =~ s/_.+//g;
						#$results{$file_name}{$gene_name} = $type." ".$result->query_description." (Range: ".$hsp->start('query')." ".$hsp->end('query').")"; ####For Austin
						$results{$file_name}{$gene_name} = $type;
						push(@scheme, %results);
						return \@scheme;
				}
					#if the percent identity of the hsp is greater than 85%, then proceed:
					elsif ( $hsp->num_identical >= ($hit->length * 0.85)) {
					# If the length of the hsp is at least 80% the length of the hit
						#if (($hsp->length('total') >= ( $hit->length * 0.85))) {
						#the description, bit score, evalue, and percent identity of the results in the blast file
							($type = $hit->accession) =~ s/_.+//g;
							#$percent_identity = sprintf("%.2d", $hsp->percent_identity);
							#$results{$file_name}{$gene_name} = $type."($percent_identity%) ".$result->query_description." (Range: ".$hsp->start('query')." ".$hsp->end('query').")"; ####For Austin
							$results{$file_name}{$gene_name} = $type;
							#$results{$file_name}{$gene_name} = $type."($percent_identity%)";
							push(@scheme, %results);
							return \@scheme;
					} else {
						$type = "-";
						$results{$file_name}{$gene_name} = $type;
						push(@scheme, %results);
						return \@scheme;
						#else {}
					#}
				}
			}
		}
	}

	unless (length $type) {
		$type = "-";
		$results{$file_name}{$gene_name} = $type;
		push(@scheme, %results);
		return \@scheme;
	}
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
  maxWidth	: '1500',
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





