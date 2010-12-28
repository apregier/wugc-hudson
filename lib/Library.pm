package Library;

use UR;
use LWP::Simple;
use Defaults;

sub snapshot_namespaces {
    # create a nice path for working not likely to get blasted
    my $timestamp = UR::Time->now();
    $timestamp =~ s/\s/_/g;
    my $working_path = join('-', 'snapshot-working', $ENV{USER}, $timestamp);
    $working_path = '/tmp/' . $working_path;
    system "mkdir $working_path";
    my $snapshot_path = shift;
    if (-e $snapshot_path) { die "We don't want to destroy what you've got, so pass a non-existant target path."; }
    `mkdir $snapshot_path`;
    `mkdir $snapshot_path/lib`;
    `mkdir $snapshot_path/lib/perl`;
    my @repos = @_;
    my $recorded_hash;
    my $command;
    for my $repo (@repos) {
        $command = "cd $working_path; git clone " . $repo->{'repository_url'} . " " . $repo->{'repository_name'};
        `$command`;
        $command = "cd $working_path/" . $repo->{'repository_name'} . "; git show --pretty=oneline " . $repo->{'hash'} . " | tr -d '\n' | cut -d ' ' -f1";
        $recorded_hash = `$command`;
        chomp $recorded_hash; chomp $recorded_hash; chomp $recorded_hash;
        for my $ns ( @{ $repo->{'namespaces'} } ) {
            print "Beginning work on namespace $ns\n";
            $command = "cd $working_path/" . $repo->{'repository_name'} . "/" . $repo->{'library_path'} . "; git archive " . $repo->{'hash'} . " $ns | tar -x -C $snapshot_path/lib/perl";
            `$command`;
            $command = "cd $working_path/" . "/" . $repo->{'repository_name'} . "/" . $repo->{'library_path'} . "; git archive " . $repo->{'hash'} . " $ns.pm | tar -x -C $snapshot_path/lib/perl";
            `$command`;
        }
        # record hash in revisions.txt
        $command = 'echo "' . $repo->{'repository_name'} . ' ' . $recorded_hash . '" >> ' . $snapshot_path . "/revisions.txt";
        `$command`;
    }
    $command = "rm $working_path/ -rf";
    `$command`;
}

####
# Parse Hudson's build status RSS feed and return the most recent successful build from today.
#
# Yes I am using Regexs to parse Xml. See:
# http://stackoverflow.com/questions/1732348/regex-match-open-tags-except-xhtml-self-contained-tags/1732454#1732454
####
sub check_for_new_build { # returns new build number or 0 if none.
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
    $mon = ($mon+1); # mon is 0 indexed by default.

    my $rss_feed = get($Defaults::RSS_FEED_URL);

    my @entries = ($rss_feed =~ /<entry>(.+?)<\/entry>/g);

    foreach (@entries) {
        $_ =~ /<published>\d{4}-(\d+)-(\d+)T.+<\/published>/; # $1 is month, $2 is day
        if ($1 == ($mon) && $2 == $mday) { # this build is from today.
            $_ =~ /<title>Genome #(\d+)\s\((\w+)\)<\/title>/;
            if ($2 eq "SUCCESS") {
                return $1;
            }
        }
    }
    return 0;
}

sub get_workflow_hash { return get_something_hash(shift, "workflow"); }

sub get_genome_hash { return get_something_hash(shift, "genome"); }

sub get_ur_hash { return get_something_hash(shift, "UR"); }

sub get_something_hash {
    my $build_number = shift;
    my $something_name = shift;
    my $revision_txt_path = $Defaults::BUILD_PATH . '/' . $build_number . '/revision.txt';
    open (revision_fh, $revision_txt_path);

    while (<revision_fh>) {
        if ( $_ =~ /$something_name/ ) {
            $_ =~ /$something_name\s(.+)/;
            return $1;
        }
    }
}

# Shamelessly stolen from Genome/Utility/Text.pm
sub model_class_name_to_string {
    my $type = shift;
    $type =~ s/Genome::Model:://;
    my @words = split( /(?=(?<![A-Z])[A-Z])|(?=(?<!\d)\d)/, $type);
    return join('_', map { lc $_ } @words);
}

sub users_to_addresses {
    my @users = @_;
    return join(',', map { $_ . '@genome.wustl.edu' } @users);
}

sub send_mail {
    my %params = @_;
    my $subject = $params{subject} || die "No subject provided to send_mail method!";
    my $data = $params{body} || die "No messsage body provied to send_mail method!";
    my $from = $params{from} || sprintf('%s@genome.wustl.edu', $ENV{'USER'});
    my $cc = $params{cc} || '';
    my $to = $params{to} || die "No to parameters provided to send_mail method!"; 

    my $msg = MIME::Lite->new(
        From => $from,
        To => $to,
        Subject => $subject,
        Data => $data,
        Cc => $cc,
    );
    $msg->send();
}

1;
