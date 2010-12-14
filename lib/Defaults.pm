package Defaults;

our $RSS_FEED_URL = 'http://hudson.gsc.wustl.edu/job/Genome/rssAll';
our $BASE_DIR = '/gsc/scripts/opt/genome';
our $BUILD_PATH = $BASE_DIR . '/snapshots/unstable';
our $TESTED_PATH = $BASE_DIR . '/snapshots/tested';
our $STABLE_PATH = $BASE_DIR . '/snapshots/stable';
our $STABLE_PIPELINE = $BASE_DIR . '/stable-pipeline';
our $STABLE_WEB = $BASE_DIR . '/stable-web';
our $STABLE_USER = $BASE_DIR . '/stable-user';
our $SNAPSHOT_PATH = $ENV{HOME} . '/.hudson_snapshot';

our $UR_REPOSITORY = 'git://github.com/sakoht/UR.git';
our $WORKFLOW_REPOSITORY = 'ssh://git.gsc.wustl.edu/srv/git/workflow.git';
our $GENOME_REPOSITORY = 'ssh://git.gsc.wustl.edu/srv/git/genome.git';