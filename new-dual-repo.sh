#!/bin/zsh -f
# Purpose: Create a new git repo that will be sent to both GitHub and BitBucket
#
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2018-08-23

NAME="$0:t:r"

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
else
	PATH='/usr/local/scripts:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin'
fi

	# set this to PRIVATE='true' to make private repos by default.
	#
	# Notes:
	#	1. you must have a paid GitHub account to create private repos
	#
	#	2. if you want to make your repos private by default, add a line
	#
	#			PRIVATE='true'
	#
	#	   to the "$HOME/.config/github-and-bitbucket.txt" file
	#  	   and you can maintain your default preference regardless of
	#	   what the default is in the official git repo for new-dual-repo.sh
PRIVATE='false'

if [[ -e "$HOME/.config/github-and-bitbucket.txt" ]]
then
		# You can define all the variables below in this file if you prefer
	source "$HOME/.config/github-and-bitbucket.txt"

else
		# Or set them here if you prefer

	# Change this to your favorite Git GUI app
	GIT_APP='Sourcetree'

	GITHUB_USERNAME='CHANGE_TO_YOUR_GITHUB_USERNAME'

	BITBUCKET_USERNAME='CHANGE_TO_YOUR_BITBUCKET_USERNAME'

	# Create at: https://github.com/settings/tokens
	GITHUB_PERSONAL_ACCESS_TOKEN="REPLACE_THIS_WITH_THE_REAL_VALUE"

	# Create at: https://bitbucket.org/account/user/$BITBUCKET_USERNAME/app-passwords
	BITBUCKET_APP_PASSWORD='REPLACE_THIS_WITH_THE_REAL_VALUE'

fi

zmodload zsh/datetime

TIME=`strftime "%Y-%m-%d--%H.%M.%S" "$EPOCHSECONDS"`

function timestamp { strftime "%Y-%m-%d--%H.%M.%S" "$EPOCHSECONDS" }

GITHUB_CURL_LOG="$HOME/Desktop/$NAME.github-api-response.$TIME.log"

BITBUCKET_CURL_LOG="$HOME/Desktop/$NAME.bitbucket-api-response.$TIME.log"

DESCRIPTION='Description to come.'

function die
{
	echo "$NAME: $@"
	exit 1
}

[[ -e "$PWD/.git" ]] && die "$PWD already has a '.git' in it"

for ARGS in "$@"
do
	case "$ARGS" in
		-d|--description)
				shift
				DESCRIPTION="$1"
				shift
		;;

		--public)
				PRIVATE="false"
				shift
		;;

		--private)
				PRIVATE="true"
				shift
		;;

		--name)
				shift
				REPO_NAME="$1"
				shift
		;;

		-*|--*)
				echo "	$NAME [warning]: Don't know what to do with arg: $1"
				shift
		;;

	esac

done # for args

if [[ "$REPO_NAME" == "" ]]
then
	if [ "$#" = "0" ]
	then
		REPO_NAME=${PWD##*/}
	else
		REPO_NAME="$@"
	fi
fi

	# remove any spaces in the repo name because that’s a no-no
	# ¿ @TODO ? - should we automatically lowercase the REPO_NAME? That seems to be a convention too.
REPO_NAME=$(echo "$REPO_NAME" | tr -s ' ' '-')

if [ "$DESCRIPTION" = "" -o "$DESCRIPTION" = "Description to come." ]
then
	read "?Short Description of '$REPO_NAME': " DESCRIPTION
fi

[[ "$REPO_NAME" == "" ]] && die "\$REPO_NAME is empty"

########################################################################################################################
## BITBUCKET SECTION - START

curl -sS --location --fail -i -X POST \
	-u "${BITBUCKET_USERNAME}:${BITBUCKET_APP_PASSWORD}" \
	-H "Content-Type: application/json" \
	-d "{ \"description\": \"$DESCRIPTION\", \"scm\": \"git\", \"is_private\": \"$PRIVATE\" }" \
	"https://api.bitbucket.org/2.0/repositories/{$BITBUCKET_USERNAME}/{$REPO_NAME}" 2>&1 > "$BITBUCKET_CURL_LOG"

CURL_EXIT_BITBUCKET="$?"

if [ "$CURL_EXIT_BITBUCKET" = "0" ]
then
	echo "$NAME: Successfully created '$REPO_NAME' on BitBucket"

		# if we were successful, move the log to the trash
	mv -n "$BITBUCKET_CURL_LOG" "$HOME/.Trash/"

else
	echo "$NAME: failed to create '$REPO_NAME' on BitBucket"

	[[ -s "$BITBUCKET_CURL_LOG" ]] && echo "$NAME: see '$BITBUCKET_CURL_LOG' for details."

	[[ ! -s "$BITBUCKET_CURL_LOG" ]] && mv -n "$BITBUCKET_CURL_LOG" "$HOME/.Trash/"

	exit 1
fi

## BITBUCKET SECTION - END
########################################################################################################################

########################################################################################################################
# GITHUB SECTION - START

curl -sS --location --fail -i \
-H "Authorization: token $GITHUB_PERSONAL_ACCESS_TOKEN" \
-d "{\"name\": \"$REPO_NAME\", \"auto_init\": false, \"private\": $PRIVATE, \"description\": \"$DESCRIPTION\" }" \
https://api.github.com/user/repos 2>&1 > "$GITHUB_CURL_LOG" \
|| die "Failed to create repo on GitHub"

egrep -q '^HTTP/1.1 201 Created' "$GITHUB_CURL_LOG"

CURL_EXIT_GITHUB="$?"

if [ "$CURL_EXIT_GITHUB" = "0" ]
then
	echo "$NAME: Successfully created '$REPO_NAME' on GitHub"

		# if we were successful, move the log to the trash
	mv -n "$GITHUB_CURL_LOG" "$HOME/.Trash/"

else
	echo "$NAME: failed to create '$REPO_NAME' on GitHub"

	[[ -s "$GITHUB_CURL_LOG" ]] && echo "$NAME: see '$GITHUB_CURL_LOG' for details."

	[[ ! -s "$GITHUB_CURL_LOG" ]] && mv -n "$GITHUB_CURL_LOG" "$HOME/.Trash/"

	exit 1
fi

# GITHUB SECTION - END
########################################################################################################################

[[ ! -e README.md ]] && echo "# $REPO_NAME\n\nDetails to come." >> README.md

git init 						|| die "git init failed. That seems inauspicious."
git add README.md				|| die "git add README.md failed"
git commit -m "Added bare README"	|| die "git commit failed"

if [[ ! -e .gitignore ]]
then
	# create a sane .gitignore for Mac users

cat <<EOINPUT > .gitignore
.DS_Store
.DS_Store?
.Spotlight-V100
.Trashes
Icon
Icon*
EOINPUT

fi

[[ -s .gitignore ]] || die "Failed to create .gitignore"

git add .gitignore || die "Failed to 'git add .gitignore'"

git commit -m "Added .gitignore" || die "Failed to commit .gitignore"

git remote add origin "git@github.com:${GITHUB_USERNAME}/${REPO_NAME}.git" || die "git remote add origin failed "

git remote set-url origin --push --add "git@github.com:${GITHUB_USERNAME}/${REPO_NAME}.git" || die "git remote set-url (github) failed"

git remote set-url origin --push --add "git@bitbucket.org:${BITBUCKET_USERNAME}/${REPO_NAME}.git" || die "git remote set-url (BitBucket) failed"

git push -u origin master || die "git push failed"

git remote -v || die "git remote -v failed"

########################################################################################################################
##
## if we get here everything went according to plan

if [ -e "/Applications/${GIT_APP}.app" -o -e "$HOME/Applications/${GIT_APP}.app" ]
then

	echo "$NAME: Phew. Everything seemed to work. Adding $PWD to ${GIT_APP} now."
	open -g -a "${GIT_APP}" "$PWD"

else
	echo "$NAME: Everything seemed to work, but ${GIT_APP}.app isn't installed, so I can't add $PWD to it."
fi

open -g "https://bitbucket.org/${BITBUCKET_USERNAME}/${REPO_NAME}/src/master/"

open -g "https://github.com/${GITHUB_USERNAME}/${REPO_NAME}"

echo "$NAME: opened 'https://github.com/${GITHUB_USERNAME}/${REPO_NAME}' and 'https://bitbucket.org/${BITBUCKET_USERNAME}/${REPO_NAME}/src/master/' in your default browser."

exit 0

#EOF
