#!/bin/bash

#Color variables
W="\033[0m"
B='\033[0;34m'
R="\033[01;31m"
G="\033[01;32m"
OB="\033[44m"
OG='\033[42m'
UY='\033[4;33m'
UG='\033[4;32m'

#Check if you are in the directory where WordPress is installed
FILE='wp-config.php'
if [ -f "$FILE" ]; then

# Get files and folders owner and group for actual WordPress installation
file_meta=($(ls -l $FILE))
file_owner="${file_meta[2]}"
file_group="${file_meta[3]}"

# Get DB_NAME, DB_USER, and DB_PASS inside the wp-config file
db_name=$(sed -n "s/define( *'DB_NAME', *'\([^']*\)'.*/\1/p" $FILE)
db_user=$(sed -n "s/define( *'DB_USER', *'\([^']*\)'.*/\1/p" $FILE)
db_pass=$(sed -n "s/define( *'DB_PASSWORD', *'\([^']*\)'.*/\1/p" $FILE)

echo ""
echo -e "==================================\n$OB WordPress Clone$W \n=================================="
echo ""

# Copy files to new location
new_location_prompt() {
    apwd=$(pwd)
    echo "Please indicate the new Directory..."
    read -p "$(echo -e "Complete Target Directory (e.g. without the last slash $OB"$apwd"/newSite2$W): \n> ")" target_directory
    NewLocation=${target_directory}
    echo ""

    prompt_confirm
}

prompt_confirm() {
    read -p "Is this new location correct? [y/n] " response
    case "$response" in
        [yY])
            echo -e "==================================\n$OB Duplicating the directory...$W \n=================================="
            echo -e "$G>> Copying...$W please wait.....\n"

            cp -r . $NewLocation && chown -R $file_owner:$file_group $NewLocation

            find $NewLocation -type d -exec chmod 755 {} \;
            find $NewLocation -type f -exec chmod 644 {} \;
            echo ""
            echo "All ready! The new location is: $NewLocation"
            echo ""
            ;;
        [nN]) 
            echo ""
            new_location_prompt
            ;;
        *) 
            echo ""
            echo "Please select Yes[y] or No[n]"
            prompt_confirm
            ;;
    esac
}

new_location_prompt

# Generate new URL and New Database
new_url_prompt() {
    echo "Please indicate the new URL of Website..."
    read -p "$(echo -e "Complete Site URL (e.g. without the last slash$R https://newsite.com$W or$R https://site.com/wp2$W): \n> ")" target_directory
    new_URL="$target_directory"
    echo ""

    prompt_confirm_url
}

prompt_confirm_url() {
    read -p "Is this new URL correct? [y/n] " response
    case "$response" in
        [yY])
            rnumber=$((RANDOM%995+1))
            nwdt="${file_owner}_wps${rnumber}"

            echo -e "==================================\n$OB Duplicating the database...$W \n=================================="
            echo -e "$G>> Duplicating...$W please wait.....\n"

            # Create database and user with privileges
            mysql -u root -p -e "CREATE DATABASE $nwdt;"
            mysql -u root -p -e "CREATE USER '$nwdt'@'localhost' IDENTIFIED BY '$db_pass';"
            mysql -u root -p -e "GRANT ALL PRIVILEGES ON $nwdt.* TO '$nwdt'@'localhost';"

            # Dump original database to the new database
            mysqldump $db_name -u $db_user -p$db_pass > "$db_name"_orig.sql
            mysql $nwdt -u $nwdt -p$db_pass < "$db_name"_orig.sql

            # Delete generated database dump file
            rm -rf "$db_name"_orig.sql

            echo -e "==================================\n$OB Creating new URL...$W \n=================================="

            # Set new URL in DB
            db_prefix=$(grep table_prefix $FILE | awk -F"'|'" '{print$2}')
            old_URL=$(mysql $db_name -u $db_user -p$db_pass -se "SELECT option_value FROM "${db_prefix}options WHERE option_name LIKE '%siteurl%'")

            SQLUpdate1="UPDATE "${db_prefix}options SET option_value = replace(option_value, '$old_URL', '$new_URL') WHERE option_name = 'home' OR option_name = 'siteurl';"
            SQLUpdate2="UPDATE "${db_prefix}posts SET guid = replace(guid, '$old_URL', '$new_URL');"
            SQLUpdate3="UPDATE "${db_prefix}posts SET post_content = replace(post_content, '$old_URL', '$new_URL');"
            SQLUpdate4="UPDATE "${db_prefix}postmeta SET meta_value = replace(meta_value, '$old_URL', '$new_URL');"

            mysql $nwdt -u $nwdt -p$db_pass -e "${SQLUpdate1}${SQLUpdate2}${SQLUpdate3}${SQLUpdate4}"

            # Update wp-config.php file
            sed -i -e "s/$db_name/$nwdt/g" $NewLocation/$FILE
            sed -i -e "s/$db_user/$nwdt/g" $NewLocation/$FILE

            echo ""
            echo "All ready! The new URL is: $new_URL"
            echo "You can also enter the administrator: ${new_URL}/wp-admin"
            echo ""
            ;;
        [nN])
            echo ""
            new_url_prompt
            ;;
        *)
            echo ""
            echo "Please select Yes[y] or No[n]"
            prompt_confirm_url
            ;;
    esac
}

new_url_prompt

echo -e "\nCleaning and deleting files and folders created by this script\n$UG>> Everything is ready!....$W\n"

else
    echo -e "\n$FILE does not exist."
    echo -e "REMEMBER: in order to use this script, you must place it inside the folder where WordPress was installed\nFor example:$B /var/www/html/wordpress$W or$B /home/kusanagi/filer.salo.hair$W"
    echo ""
    exit 1
fi
