package repcr;

use Time::Piece;
use Data::Dumper qw(Dumper);


####################################################
# Object oriented module for creating a new object
# I don't really know what's going on here
sub new {
	my ($class, @args) = @_;
	bless {}, $class;
}

#########################3
sub re_pcr {
	# Import the variables
	my ($classinfo, $genome, $forwardPrimer, $reversePrimer, $mismatches, $align) = @_;
	# Re-assign $genome to its proper variable type - hash
	my %genome = %$genome;
	
	# Initialise variables
	my (%report, $alignment, $query, $databaseLength);

	# Get the date and time for naming outfiles.
	my $time =  localtime;
	my $date = $time->ymd;	
	my $hms = $time->hms("_");	
	$dateTime = $date.$hms;
	
	# Provide the location of the re-PCR executable
	my $repcr = "/home/blais/Bioinformatics/epcr/Linux-x86_64/re-PCR"; 
	
	# Traverse the hash and pull the list/hash key/value pairs
	while (my ($hash, $list) = each %genome) {
		# Name the outfile
		my $outfile = "/var/www/PrimerValidatr/outputs/" . $dateTime . ".out";
		# Prepare the system call
		my $exec = "$repcr -s $hash -n $mismatches -g 0 $forwardPrimer $reversePrimer 100-2000 -G > $outfile";
		# Perform the system call
		system($exec);

		### Read Genbank text file (XXXXlist.txt) that links accession to genome sequences (custom)
		open(INPUT, "<", $list);
		# Place data in an array
		@strainInfo = (<INPUT>);
		$databaseLength += scalar(@strainInfo);
		close IN;

		# Parse the output file
		open(OUT, "<", $outfile);

		# Initialise $line - allows for proper parsing of each record
		my $line = 1;

		###Parse output 
		while(<OUT>){
			#STS-1	gi|153950938|ref|NC_009707.1|	+	287948	288780	15	4	833/0-1000
			#   STS                         STS-1   AG-C--CTCCGAGCAGCCGGGCAAA...786...GGCTCAGGACGCGCT--T--TGAATGGG-G  
			#                                       || |  | || |  || || |||||   786    || || || | |||  |  || | ||| |  
			#   Seq gi|153950938|ref|NC_009707.1| acAGACGAC-CCTAA-AGGCGTGCAAA...786...AGCACAAGA-G-GCTAATCATG-A-GGGTGat
			##########################################################################

			chomp;
			if(/^STS-1/){
				# splits on whitespace breaks
				my @a = split(/\s+/);
				# counter			
				$count = 1;
				# $query is set to gi|153950938|ref|NC_009707.1|			
				$query = $a[1];
				# Remove the pipes (|) from the gi tag
				($queryNoPipe = $query) =~ s/\|/\\|/g;
				# Find the corresponding entry in @strainInfo to $query
				foreach my $genomeData (@strainInfo) {
					# Split on commas
					$genomeData =~ s/\,//g;
					# If the data in @strainInfo matches $queryNoPipe
					if ($genomeData =~ /$queryNoPipe/) {
						# Find the data that follows $queryNoPipe
						$genomeData =~ /$queryNoPipe(.+)/ig;
						# Remove unnecessary words from the match and assign the match to $strainNames
						($strainNames = $1) =~ s/chromosome|complete|genome|contig|gcontig|sequence|whole|genome|shotgun//g;
					}
				}
				# Split the data (833/0-1000) on the "/" to get the length of the match
				$a[7] =~ s/\/.*//g;
				# Populate %report with the necessary data
				$report{$query}{'name'} = $strainNames;
				$report{$query}{'strand'} = $a[2];
				$report{$query}{'size'} = $a[7];
				$report{$query}{'mismatches'} = $a[5];
				$report{$query}{'gaps'} = $a[6];
			# If $line > 1 and $count <= 4, then add the alignment to $alignment
			} elsif($line > 1){
				$count++;
				# Check to see if the alignment is desired
				if ($align eq 'ON') {
					# Append the alignment to the hash
					($var = $_) =~ s/#|STS|-1|$queryNoPipe|Seq//g;
					$var =~ tr/a-z/!/;
					$var =~ s/!//g;
					$var =~ s/\n/<br>/g;
					$var =~ s/\s(\d+)\s/&nbsp&nbsp$1&nbsp&nbsp/g;
					
					$report{$query}{'align'} .= $var . "<br>" if ($count <= 4);
				} else {
					# The alignment will be a placeholder
					$report{$query}{'align'} = 'NA';
				}
			}
		# Increment $line 
		$line++;

		}
		
		close OUT;
		# Remove the outfile
		my $cleanjb = "rm -rf $outfile";
		#system($cleanjb);
	}
	#print Dumper(%report);
	return (\%report, $databaseLength);
}

# Modules need to end on something that evaluates to true
1;
