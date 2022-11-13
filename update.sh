# the directory of the script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# the temp directory used, within $DIR
# omit the -p parameter to create a temporal directory in the default location
WORK_DIR=`mktemp -d -p "$DIR"`

# check if tmp dir was created
if [[ ! "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
  echo "Could not create temp dir"
  exit 1
fi

# deletes the temp directory
function cleanup {
  rm -rf "$WORK_DIR"
  echo "Deleted temp working directory $WORK_DIR"
}

# register the cleanup function to be called on the EXIT signal
trap cleanup EXIT

cd $WORK_DIR

declare -a suffixes=("k8s" "kustomize" "oci" "mdbook")

branch_name="workflow/sync"
hash=$(git log -n 1 --pretty=format:"%H")
body="Synchronzing workflow pants-plugin-workflow-template @ $hash"

for suffix in "${suffixes[@]}"; do
	(
    	git clone "git@github.com:tgolsson/pants-backend-$suffix.git"

    	rm -rf "pants-backend-$suffix/.github/*"
    	cp -r $DIR/{workflows,*.yml} "pants-backend-$suffix/.github/"

    	pushd pants-backend-$suffix
    	git add .
    	if [[ $(git diff-index --quiet --cached HEAD --) -eq 0 ]]; then
			git checkout -b "workflow/sync"
			git commit -m "Update workflows"

    		git push -u origin "workflow/sync"
			existing_prs=$("$DIR/gh" pr list --state open -S "in:title Update common workflows" --json id -q 'length')
			if [[ existing_prs -eq 0 ]]; then
				"$DIR/gh" pr create -b "$body" -t "Update common workflows" -B main -H "$branch_name"
			else
				"$DIR/gh" pr edit "$branch_name" -b "$body" -t 'Update common workflows' && gh pr reopen "$branch_name"
			fi

    	fi
    	popd
	) &
done

wait
