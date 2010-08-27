

use strict;
use warnings;

use XML::Simple;
use Data::Dumper;

use Mail::Sendmail;
use File::chdir '$CWD';

#
# it only makes sense to run this on the last hudson build to finish since it looks
# at junit files in the workspace which is overwritten each time
#

my $hudson_build_id = $ARGV[0] || die 'first argument should be a hudson build id';
chomp($hudson_build_id);

my $test_result_base_path = '/gscuser/mjohnson/.hudson/jobs/Genome/workspace/test_result';
my $build_base_path = join('/', '/gscuser/mjohnson/.hudson/jobs/Genome/builds', $hudson_build_id);

my $url = join('/', 'http://hudson:8090/job/Genome', $hudson_build_id);

my $junit_pathname = join( '/',
    $build_base_path,
    'junitResult.xml' 
);

my $alerts_sent = {};

my $xml = XMLin($junit_pathname) || die "failed to parse junit results file: $junit_pathname";

    for my $s ($xml->{'suites'}->{'suite'}) {

        for my $test_filename (keys %{$s}) {

            for my $case ($s->{$test_filename}->{'cases'}->{'case'}) {
                next if !$case;

                if (ref($case) eq 'ARRAY') {
                    for my $test (@$case) {
                        check_test($test); 
                    }
                } else {   # HASH
                    check_test($case);
                }
            }
        }
    }


exit;

sub get_revision_info {

    my $r = {};
    my $path = join ('/', $build_base_path, 'revision.txt');

    open(my $fh, $path);
        while(<$fh>) {
            my ($ns, $revision) = split(/\s+/);
            $r->{$ns} = $revision;
        }
    close($fh);

    return $r;
}

sub check_test {

    my ($test) = @_;

    if (! defined ($test->{'errorStackTrace'})) {
        # this test was not a failure
        return;
    }

    my ( $test_pathname, $details ) = get_test_details($test);

    # only send 1 email per test file, not 1 per test line
    if ( ! defined($alerts_sent->{$test_pathname}) ) {
        $alerts_sent->{$test_pathname} = 1; 
        send_alert($test);
    }

    return 1;
}

sub send_alert {

    my ($test) = @_;

    my ( $test_pathname, $details ) = get_test_details($test);
    my $failures = $details->{'failures'};
    my $tests    = $details->{'tests'};
    my $out      = $details->{'system-out'};

    my $max = 2**12; # 4k
    my $truncated = '';
    if (length($out) > $max) {
        $out = substr($out, 0, $max); # truncate output
        $truncated = "Output was truncated because it was too large. Visit the hudson URL above for the whole everything.";
    }

    my ($filename) = $test_pathname =~ /^.*\/(.*)$/;

    my $revision = get_revision_info();
    my $ur       = $revision->{'UR'} || 'unknown';
    my $genome   = $revision->{'genome'} || 'unknown';
    my $workflow = $revision->{'workflow'} || 'unknown';

    my @editors = git_blame($test_pathname);    # sorted by most ownership of test and module

    my @to = splice( @editors, 0, 3 );
    @to = map { $_ . '@genome.wustl.edu' } @to;
    my $to = @to > 0 ? join( ',', @to ) : 'apipe@genome.wustl.edu';

    my $cc = join(',', 'ssmith', 'jedlred');
    my $bcc = join(',', 'jlolofie');

    my $subject = "$filename";

    my $body = <<"_BODY_";

 failed test: $test_pathname 
      not ok: $failures / $tests

hudson build: $url    
      genome: $genome
    workflow: $workflow
          UR: $ur

Output for this test follows. $truncated

----start of output------
$out
----end of output------

To: $to
Cc: $cc
_BODY_

#    $to = 'jlolofie@genome.wustl.edu';
#    $cc = '';

    my $mail = {
        To      => $to,
        Cc      => $cc,
        Bcc     => $bcc,
        From    => 'ssmith@genome.wustl.edu',
        Subject => $subject,
        Message => $body,
    };

    sendmail(%$mail) || die "couldnt send the mail to $to about $subject";

    return 1;
}

sub get_test_details {

    my ($test) = @_;

    my $test_pathname = $test->{'className'};

    if ($test_pathname !~ /^\w+\_t$/) {
        $test_pathname = $test->{'testName'};
    }
    
    if ($test_pathname !~ /^\w+\_t$/) {
        print Dumper $test;
        die 'neither className nor testName looked right (see dump above)';
    }

    $test_pathname =~ s/(.*)_t/$1.t/;
    $test_pathname =~ s/_/\//g;

    my $junit_xml_pathname = join('/', $test_result_base_path, $test_pathname);
    $junit_xml_pathname .= '.junit.xml';

    # this stuff uses the hudson "workspace" which is not saved, so this junit result file
    # refers to the latest hudson build!

    my $xml = XMLin($junit_xml_pathname) || die "failed to parse the junit detail file: $junit_xml_pathname";
    my $ts = $xml->{'testsuite'} || return;

    return ($test_pathname, $ts);
}


sub git_blame {

    my ($test_pathname) = @_;

    $test_pathname = join('/', '/gscuser/jlolofie/dev/git/genome/lib/perl/Genome', $test_pathname);

    my $module_pathname = $test_pathname;
    $module_pathname =~ s/^(.*)\.t$/$1.pm/;

    my $winners = {};
    for my $file ($test_pathname, $module_pathname) {

        next if ! -f $file;

        my $user = {};

        my ($base_path) = $file =~ /^(.*)\/.*$/;
        local $CWD = $base_path; # git requires --git-dir or pwd being git checkout
        my $cmd = "/gsc/scripts/sbin/gsc-cron /gsc/bin/git blame $file";
        my @out = `$cmd`;

            for my $line (@out) {
                my ($hash, $fn, $u) = split(/\s+/, $line);
                $u =~ s/\(//g;

                next if $u =~ /[A-Z]/;
                next if grep /$u/, ('jpeck');
                $user->{$u}++;
            }

        my @sorted = sort { $user->{$b} <=> $user->{$a} } keys %$user;

        my $i = -1;

        while (++$i < @sorted && $i <= 3) {

            $winners->{$sorted[$i]}++;
        }

    }
    return if !$winners;

    return sort { $winners->{$b} <=> $winners->{$a} } keys %$winners;
}


#~$ vim /gscuser/mjohnson/.hudson/jobs/Genome/workspace/test_result/Model/Tools/BedTools/Coverage.t.junit.xml

# wtf sometimes its className, sometimes testName
#'className' => 'Model_Tools_DetectVariants_VarScan_t',
#'errorDetails' => 'not ok 6 - No differences in output from expected result from running var-scan for this version and parameters',
#'failedSince' => '94',



