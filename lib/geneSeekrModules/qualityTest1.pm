# Packages start with the package statement
package qualityTest;
#use strict;
use warnings;
use Cwd;
use Time::Piece;
use threads;
use Bio::SearchIO;
use Data::Dumper qw(Dumper);

#########################
use CGI::Carp 'fatalsToBrowser';
use CGI qw/:standard *table/;
use lib "/usr/lib/cgi-bin/lib";
use CGI qw/:all/;
use HTML;
use CGI::Pretty qw( :html3 );
##########################
use parent qw(Exporter);

our $dateTime;

sub qualityChecker {		
		
	my $path = getcwd;

	# This start time will be used in calculating the total time of the run
	my $start_time = time;

	# Initialise variables
	my (@threads_formatQualitydb, @qualityGenes, @sequenceFiles, @cpus, @threads_quality_blast);
	my %strain_quality_data;

	# Determine the number of threads present in the system
	@cpus = `awk '/^processor/ { N++} END { print N }' /proc/cpuinfo`;
	chomp @cpus;

	# The files must be in the "sequences" subfolder. This subfolder must only have sequences that you wish to examine, or the program won't be able to find them
	chdir ("$path/uploads");

	@sequenceFiles = glob("*.fa*");

	# Quality metric genes must be stored in the qualityTest folder
	chdir ("$path/qualityTest");
	@qualityGenes = glob("*.tfa");
	
	# Multi-threaded approach to format the database
	while (scalar(@threads_formatQualitydb) < @cpus) {
		# Loop through each file to be subtyped
		foreach (@qualityGenes) {
			# Make a new thread using the formatdb subroutine - pass appropriate values to subroutine
			my $t = threads->new(\&formatdb, $_);
			# Output data to @threads. Right now, all this does is increase the size for the scalar(@threads) portion of the while loop
			push(@threads_formatQualitydb,$t);
		}
	}

	# This loop ensures that each thread is complete before terminating
	foreach (@threads_formatQualitydb) {
		# The join command is responsible for ensuring that all threads are complete
		my $num = $_->join;
	}
	
	chdir ("$path/tmp");
	#unlink glob ("*.blast");
	# Using multi-threaded approach
	# This while loop should ensure that the limit of the number of threads is the number of cpus
	while (scalar(@threads_quality_blast) < @cpus) {
		# Loop through each file to be subtyped
		foreach my $gene (@qualityGenes) {
				foreach my $sequence (@sequenceFiles) {
				# Make a new thread using the blast subroutine - pass appropriate values to subroutine
				my $r = threads->new(\&blast, $path, $gene, $sequence);
				# Output data to @threads. Right now, all this does is increase the size for the scalar(@threads) portion of the while loop
				push(@threads_quality_blast,$r);
			}
		}
	}

	# This loop ensures that each thread is complete before terminating
	foreach (@threads_quality_blast) {
		my $num = $_->join;
	    # As the values returned from the blast subroutine are an array of hashes, $num must be treated as such - @$num
	    foreach my $blast_quality_return (@$num) {
	    	# $a is the hash %results pushed to @scheme - must treat it as a hash in order to extract values
	    	while (my ($blast_quality_strain, $blast_quality_allele) = each %$blast_quality_return) {
	    		# Reformat the data back into a hash - $strain_data{"strain"}{"gene"} = "allele"
	    		$strain_quality_data{$$num[0]}{$blast_quality_strain} = $blast_quality_allele;
	    	}
	    }
	}
	chdir ("$path");	
	return (%quality_results);
}
#########################################
sub dateTime {
	# Get the data for naming the output file
	#my $date = Time::Piece->new->strftime('%Y%m%d');
	my $time =  localtime;
	my $date = $time->ymd;	
	my $hms = $time->hms("_");	
	$dateTime = $date.$hms;	
	return ($dateTime);
}


#########################################
# Object oriented module for creating a new object
# I don't really know what's going on here
sub new {
	my ($class, @args) = @_;
	bless {}, $class;
}

# Modules need to end on something that evaluates to true
1;


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
	my ($file_name, $gene_name, $strain, $subtype, %results, @scheme, $type, $hit_id, $hit_length, $hit_identical, $percent_identity);
	# Perform blastn search against database
	($gene_name = $gene) =~ s/.fa.*//g;
	($file_name = $sequence) =~ s/.fa.*//g;
	#print "Comparing $file_name against $gene_name.\n";
	# -task dc-megablast -lcase_masking false -soft_masking false
	system("blastn -query $path/uploads/$sequence -db $path/qualityTest/$gene -word_size 15 -outfmt 5 -max_target_seqs 1 -evalue 1e-10 -out $sequence.$gene.blast 2> /dev/null");
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
						($type = $hit->accession) =~ s/_.+|-.+//g;
						$results{$file_name}{$gene_name} = $type;
						push(@scheme, %results);
						return \@scheme;
				}
					#if the percent identity of the hsp is greater than 85%, then proceed:
					elsif ( $hsp->num_identical >= ($hit->length * 0.95)) {
					# If the length of the hsp is at least 80% the length of the hit
						#if (($hsp->length('total') >= ( $hit->length * 0.85))) {
						#the description, bit score, evalue, and percent identity of the results in the blast file
						($type = $hit->accession) =~ s/_.+|-.+//g;
						$percent_identity = sprintf("%.2d", $hsp->percent_identity);
						$results{$file_name}{$gene_name} = $type."($percent_identity%)";
						push(@scheme, %results);
						return \@scheme;
				} else {
					$type = "N";
					$results{$file_name}{$gene_name} = $type;
					push(@scheme, %results);
					return \@scheme;
					#else {}
				}
			}
		}
	}

	unless (length $type) {
		$type = "N";
		$results{$file_name}{$gene_name} = $type;
		push(@scheme, %results);
		return \@scheme;
	}
}






