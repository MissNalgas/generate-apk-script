#!/bin/bash

send_message() {
	TXT=''
	for i in $@
	do
		TXT="$TXT $i"
	done

	curl "https://lnk.mssnapps.com/api/notification" -X POST -H 'Content-Type: application/json; charset=utf-8' -d '{"message": "'"$TXT"'", "apiKey": "API_KEY_REMOVED"}'
}

print_error() {
	send_message $@
	echo $@
	exit 1
}

initial_questions() {
	echo Enter the version code development
	read version_code
	echo Enter the version name development
	read version_name
	echo Enter version code production
	read version_code_prod
	echo Enter version name production
	read version_name_prod

	echo "Development $version_code ($version_name) | Production $version_code_prod ($version_name_prod) | confirm? [yes][no]"
	read confirm_result
	if [ $confirm_result == 'yes' ]; then
		return 0;
	else
		return 1;
	fi
}

copy_dev() {
	mkdir -p ~/apks/development &&
	rm -rf ~/apks/development/* &&
	cp ./android/app/build/outputs/apk/release/app-release.apk ~/apks/development/dev$version_code\($version_name\).apk &&
	cp ./android/app/build/outputs/bundle/release/app-release.aab ~/apks/development/dev$version_code\($version_name\).aab
}

copy_prod() {
	mkdir -p ~/apks/production &&
	rm -rf ~/apks/production/* &&
	cp ./android/app/build/outputs/apk/release/app-release.apk ~/apks/production/prod$version_code_prod\($version_name_prod\).apk &&
	cp ./android/app/build/outputs/bundle/release/app-release.aab ~/apks/production/prod$version_code_prod\($version_name_prod\).aab
}

generate_development() {
	if sed -i "s/versionCode \S*/versionCode ${version_code}/" ./android/app/build.gradle
	then
		echo 'Gradle written'
	else
		print_error 'Error writing gradle'
	fi

	if sed -i "s/versionName \"\S*\"/versionName \"${version_name}\"/" ./android/app/build.gradle
	then
		echo 'Gradle written!'
	else
		print_error 'Error writing version name in gradle'
	fi

	if mv ./.env.production ./.env.production.modified && mv ./.env.development ./.env.production
	then
		echo Development variables renamed
	else
		print_error 'Error while renaming development variables'
	fi

	if npm run bundle:android && rm -rf ./android/app/src/main/res/raw && rm -rf ./android/app/src/main/res/drawable-* && npm run pack-android-release-mac
	then
		echo 'First build succesful'
	else
		print_error 'Error on first build'
	fi


	if copy_dev
	then
		echo 'Files copied!'
	else
		print_error 'Error copying files'
	fi
}

generate_production() {
	if mv ./.env.production ./.env.development && mv ./.env.production.modified ./.env.production
	then
		echo 'Dev files renamed'
	else
		print_error 'Error while renaming development variables'
	fi

	if sed -i "s/versionCode \S*/versionCode ${version_code_prod}/" ./android/app/build.gradle &&
	sed -i "s/versionName \"\S*\"/versionName \"${version_name_prod}\"/" ./android/app/build.gradle
	then
		echo 'Gradle written!'
	else
		print_error 'Error while writing gradle'
	fi


	if npm run bundle:android && rm -rf ./android/app/src/main/res/raw && rm -rf ./android/app/src/main/res/drawable-* && npm run pack-android-release-mac
	then
		echo 'Second build successful'
	else
		print_error 'Error on second build'
	fi

	if copy_prod
	then
		echo 'Files copied!'
	else
		print_error 'Error while copying production files'
	fi
}

init() {
	
	initial_questions
	if [ $? -gt 0 ]; then
		exit 1;
	fi

	generate_development && generate_production

	send_message 'Build successful!'
	echo -e "\033[1;32m Success!! \033[0m"
}

init