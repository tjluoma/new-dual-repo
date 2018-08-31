#!/bin/zsh -f
# Purpose: Create a new git repo that will be sent to both GitHub and BitBucket
#
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2018-08-23

NAME="$0:t:r"

ROOT_DIR="$HOME/.config/new-dual-repo"

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
else
	PATH='/usr/local/scripts:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin'
fi

if [[ -e "$ROOT_DIR/settings" ]]
then
		# You can define all the variables below in this file if you prefer
		# A settings.example is provided in the config directory
		# $cp config/settings.example config/settings
		# will copy the .example file to just settings which you can then edit
	source "$ROOT_DIR/settings"

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

	# set this to PRIVATE='true' to make private repos by default.
	#
	# Notes:
	#	1. you must have a paid GitHub account to create private repos
	#
	#	2. if you want to make your repos private by default, add a line
	#
	#			PRIVATE='true'
	#
	#	   to the "config/settings" file
	#  	   and you can maintain your default preference regardless of
	#	   what the default is in the official git repo for new-dual-repo.sh
	PRIVATE='false'

	LOGFILE_DIR="$HOME/Desktop"
fi

zmodload zsh/datetime

TIME=`strftime "%Y-%m-%d--%H.%M.%S" "$EPOCHSECONDS"`

function timestamp { strftime "%Y-%m-%d--%H.%M.%S" "$EPOCHSECONDS" }

GITHUB_CURL_LOG="$LOGFILE_DIR/$NAME.github-api-response.$TIME.log"

BITBUCKET_CURL_LOG="$LOGFILE_DIR/$NAME.bitbucket-api-response.$TIME.log"

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
				USE_DIRNAME_AS_REPO_NAME='no'
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
		USE_DIRNAME_AS_REPO_NAME='yes'
		REPO_NAME=${PWD##*/}
	else
		USE_DIRNAME_AS_REPO_NAME='no'
		REPO_NAME="$@"
	fi
fi

## 2018-08-29 - Bitbucket has more stringent requirements for REPO_NAME (aka "slugs") than GitHub does.
#
# For example, attempting to create a $REPO_NAME with a single capital letter causes Bitbucket to fail with this error:
#
# 	"Invalid slug. Slugs must be lowercase, alphanumerical, and may also contain underscores, dashes, or dots."
#
# Therefore, we need to make sure that '$REPO_NAME' is only those things:

REPO_NAME_REFORMATTED=$(echo "${REPO_NAME}" \
	| tr -s ' ' '-' \
	| tr "[:upper:]" "[:lower:]" \
	| tr -dc '[:alnum:]-_.' \
	| sed 's#-*$##g' \
	)

if [[ "$REPO_NAME_REFORMATTED" != "${REPO_NAME}" ]]
then
	# If we get here, there must have been some illegal characters in the recommended REPO_NAME

cat <<EOINPUT

$NAME: '${REPO_NAME}' cannot be used as the name for your git repo.

	Bitbucket requires that repo names be lowercase, alphanumerical, and may also contain underscores, dashes, or dots.

	You have 3 options:

	1) If you press 'Enter' ( ⏎ ), the repo name will be changed to: '${REPO_NAME_REFORMATTED}'.

	2) If you want to chooe a new '\$REPO_NAME' yourself, enter 'R' or 'r' (for 'Rename')

	3) If you do NOT want to continue at all, simply press 'Control-C' (⌃ C) to exit.

EOINPUT

	read "?$NAME: press 'Enter' to use the new name, 'R' or 'r' to Rename, or 'Control-C' to exit:  " ANSWER

	case "$ANSWER" in
		R*|R*|2*)

				read "?What would you like the new '\$REPO_NAME' to be? " NEW_REPO_NAME

					# Rather than loop through what we just did again to check the
					# new input, let's simply call the script again, with the
					# new repo name as an --name argument:
				exec "$0" $@ --name "$NEW_REPO_NAME"

				exit 0
		;;

	esac

	# If we get here, then the user has opted to use our suggest rename of $REPO_NAME

		# update the variable $REPO_NAME to use the newly reformatted version of itself
	REPO_NAME="${REPO_NAME_REFORMATTED}"

	if [[ "$USE_DIRNAME_AS_REPO_NAME" == "yes" ]]
	then
		# if the user did not specify the original REPO_NAME, but rather we extrapolated
		# it from the name of the directory we are in, then we should offer to rename
		# the directory we are in to match the new, reformatted $REPO_NAME,
		# but only if we can do so without overwriting an existing file/folder

		SAFE_FOLDER_NAME="$PWD:h/$REPO_NAME_REFORMATTED"

		if [[ ! -e "$SAFE_FOLDER_NAME" ]]
		then

			echo "\n${NAME}: One last question:\n	Do you want to rename the current folder '$PWD' to"
			echo "	'${SAFE_FOLDER_NAME}' to match the new, reformatted git repo name?\n"

			read "?	Type 'n' followed by the Enter / Return ⏎ key to NOT rename the folder. Any other input will rename the folder: " ANSWER

			case "$ANSWER" in
				N*|n*)
					echo "$NAME: Ok, will _not_ rename '$PWD'."
				;;

				*)
					if [[ -e "$SAFE_FOLDER_NAME" ]]
					then
						echo " ⚠️ $NAME: Sorry, I cannot rename '$PWD' to '$SAFE_FOLDER_NAME' because '$SAFE_FOLDER_NAME' already exists."
					else
						mv -v "$PWD" "$SAFE_FOLDER_NAME" || echo " ⚠️ $NAME: Failed to rename '$PWD' to '$SAFE_FOLDER_NAME'."
					fi
				;;

			esac
		fi
	fi
fi

if [ "$DESCRIPTION" = "" -o "$DESCRIPTION" = "Description to come." ]
then
	read "?Short Description of '$REPO_NAME': " DESCRIPTION
fi

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
	# create a .gitignore
	if [[ -e "$ROOT_DIR/gitignore" ]]
	then
		gitignore=$(<"$ROOT_DIR/gitignore")
		echo "$gitignore" > .gitignore
	else
		echo "# ignore these files (1 file or pattern per line)\n" > .gitignore
	fi
fi

[[ -s .gitignore ]] || die "Failed to create .gitignore"

git add .gitignore || die "Failed to 'git add .gitignore'"

git commit -m "Adds .gitignore" || die "Failed to commit .gitignore"

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
