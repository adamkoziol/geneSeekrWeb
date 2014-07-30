package upload;

use Cwd;
use Time::Piece;
use threads;
use Bio::SearchIO;
use Data::Dumper qw(Dumper);
use CGI::Carp 'fatalsToBrowser';
use CGI qw/:standard *table/;
use lib "/usr/lib/cgi-bin/lib";
use CGI qw/:all/;
#use HTML;
use CGI::Pretty qw( :html3 );
use File::Basename;
use qualityTest;
#############################################################
# This first section uploads the file(s) specified in the geneSeekr_webTool
# The code in this section was taken from: http://www.sitepoint.com/uploading-files-cgi-perl/
# The point of much of the code is to ensure that there's no malicious stuff going on
# Comments are a mixture of content from the website and my own

# This limits the file upload size to 100 GB -> 100 000 MB - 100 000 000 KB
$CGI::POST_MAX = 1024 * 10000000000;

# We’ll also create a list of “safe” characters for filenames. Some characters, such as slashes (/), are dangerous in filenames,
# as they might allow attackers to upload files to any directory they wanted. Generally speaking, letters, digits, underscores, periods, and hyphens are safe bets:
my $safe_filename_characters = "a-zA-Z0-9_.-";

# We need to create a location on our server where we can store the uploaded files. We want these files to be visible on our web site, so we should store them in a directory under our document root
my $upload_dir = "/usr/lib/cgi-bin/geneSeekr/uploads";

# The next step is to create a CGI object (we assign it to $query below); this allows us to access methods in the CGI.pm library. We can then read in the filename of our uploaded file.
#my $query = new CGI;
my $query = CGI->new();
my @filename = $query->param("queryFiles");
my $count = 0;

# As there can be multiple files uploaded, a foreach loop is used to process each file.
foreach my $filename (@filename) {

# If there was a problem uploading the file — for example, the file was bigger than the $CGI::POST_MAX setting — $filename will be empty.
# We can test for this and report the problem to the user as follows:
	if ( !$filename )	{
		print $query->header ( );
		print "There was a problem uploading your file. Please try again.";
		exit;
	}

	# We can’t necessarily trust the filename that’s been sent by the browser; an attacker could manipulate this filename to do nasty things such as upload
	# the file to any directory on the Web server, or attempt to run programs on the server. The first thing we’ll do is use the fileparse routine in the File::Basename module
	# to split the filename into its leading path (if any), the filename itself, and the file extension. We can then safely ignore the leading path.
	# Not only does this help thwart attempts to save the file anywhere on the web server, but some browsers send the whole path to the file on the user’s hard drive, which is obviously no use to us:
	# This code splits the full filename, as passed by the browser, into the name portion ($name), the leading path to the file ($path), and the filename’s extension ($extension).
	# To locate the extension, we pass in the regular expression '..*' — in other words, a literal period (.) followed by zero or more characters.
	# We then join the extension back onto the name to reconstruct the filename without any leading path.
	my ( $name, $path, $extension ) = fileparse ( $filename, '..*' );
	$filename = $name . $extension;

	# The next stage in our quest to clean up the filename is to remove any characters that aren’t in our safe character list ($safe_filename_characters).
	# We’ll use Perl’s substitution operator (s///) to do this. While we’re at it, we’ll convert any spaces in the filename to underscores, as underscores are easier to deal within URLs:
	$filename =~ tr/ /_/;
	$filename =~ s/[^$safe_filename_characters]//g;

	# Finally, to make doubly sure that our filename is now safe, we’ll match it against our $safe_filename_characters regular expression, and extract the characters that match (which should be all of them).
	# We also need to do this to untaint the $filename variable. This variable is tainted because it contains potentially unsafe data passed by the browser.
	# The only way to untaint a tainted variable is to use regular expression matching to extract the safe characters:
	if ( $filename =~ /^([$safe_filename_characters]+)$/ )	{
		$filename = $1;
	} else	{
		die "Filename contains invalid characters";
	}

	# The upload method can be employed to grab the file handle of the uploaded file (which actually points to a temporary file created by CGI.pm).
	@uploadFilehandle = $query->upload("queryFiles");
	$upload_filehandle = $uploadFilehandle[$count];

	# Using the file handle, the contents of the uploaded file can be read and saved to a new file in our file upload area.
	# The uploaded file’s filename — now fully sanitised — will be used as the name of the new file.
	# If there’s an error writing the file, the die function stops the script running and reports the error message (stored in the special variable $!).
	# Meanwhile, the binmode function tells Perl to write the file in binary mode, rather than in text mode. This prevents the uploaded file from being corrupted on non-UNIX servers (such as Windows machines).
	open ( UPLOADFILE, ">$upload_dir/$filename" ) or die "$!";
	binmode UPLOADFILE;

	while ( <$upload_filehandle> ){
	print UPLOADFILE $_;
	}
	close UPLOADFILE;
	$count++;
}

1;
