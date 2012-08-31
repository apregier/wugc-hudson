set -o nounset

echo -e "\n\n => Setting Up Test Environment..."

GIT_BASE_DIR="$1"

SNAPSHOT_LIB="/gsc/scripts/opt/genome/current/user/lib/perl"
SNAPSHOT_BIN="/gsc/scripts/opt/genome/current/user/bin"

# remove /gsc/scripts/opt/genome/current/user/*
PERL5LIB="$(echo $PERL5LIB | tr : "\n" | grep -v "$SNAPSHOT_LIB" | tr '\n' : | sed 's/:$//')"
PATH="$(echo $PATH | tr : "\n" | grep -v "$SNAPSHOT_BIN" | tr '\n' : | sed 's/:$//')"

PERL5LIB=$GIT_BASE_DIR/ur/lib:$PERL5LIB
PATH=$GIT_BASE_DIR/ur/bin:$PATH

PERL5LIB=$GIT_BASE_DIR/workflow/lib:$PERL5LIB
PATH=$GIT_BASE_DIR/workflow/bin:$PATH

PERL5LIB=$GIT_BASE_DIR/lib/perl:$PERL5LIB
PATH=$GIT_BASE_DIR/bin:$PATH

export PERL5LIB
export PATH

set +o nounset

for MODULE in UR Workflow Genome; do
    if wtf $MODULE | grep -q "$SNAPSHOT_LIB"; then echo "$MODULE found in $SNAPSHOT_LIB! Aborting!" && exit 1; fi
done

for BIN in ur workflow genome; do
    if which $BIN | grep -q "$SNAPSHOT_BIN"; then echo "$BIN found in $SNAPSHOT_BIN! Aborting!" && exit 1; fi
done

hash -r
