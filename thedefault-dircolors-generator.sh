#!/bin/bash
#
#TODO Remove unnecessary code

# Description of the script:
# genDircolors is script for creating a
# primary-mime-type/secondary-mime-type.ext directory structure, along with a
# dircolors file.

# Global variables
version="20230929b"
demo_dir="demo"
macros_dir="${demo_dir}/macros"
mime_types_dir="${demo_dir}/mime-types"
mime_types_file="${mime_types_dir}/mime.types"
s_aes="\033["
e_aes="\033[0m"
verbose="false"

# Function to print a message of a new section
print_msg() {
	local section="$1"
	local msg_welcome="Welcome to the default-dircolors-generator!

This script will generate a dircolors configuration file interactively, based
on the mime.types file in the /etc directory. It will also create a demo
directory structure with files and directories of different types, to help you
test the dircolors configuration file.
"

	if [[ ${section} == "msg_welcome" ]]; then
		divider "-"
		printf "${msg_welcome}\n"
	fi
}

# Function to print a divider
divider() {
	local divider=""
	local character="$1"
	for (( i = 0; i < 80; i++ )); do
		divider="${divider}${character}"
	done

	echo "$divider"
}

# Function to prompt user for yes/no/quit
prompt_ynq() {
	local message="$1"
	local result
	
	while true; do
		read -p "$message [y/n/q]: " result < /dev/tty
		case $result in
			[Yy]* ) return 0;;
			[Nn]* ) return 1;;
			[Qq]* ) exit 0;;
			* ) printf "Please answer yes, no or quit\n";
		esac
	done
}

# Function to create or replace a directory
create_directory() {
	local dir="$1"
	local message="
The script will use the existing directory and it will not delete or overwrite
existing files, however, it may alter their attributes.
"
	
	if [[ -d "$dir" ]]; then
		if prompt_ynq 'A "'$dir'" directory already exists. Remove?'; then
			rm -rf "$dir" && mkdir -p "$dir"
		else
			echo "$message"
		fi
	else
		mkdir -p "$dir"
	fi
}

# Function to check permissions
check_permissions() {
    local file="$1"
    local expected_perms="$2"
    local actual_perms=$(stat -c "%a" "$file")
    if [[ "$actual_perms" == "$expected_perms" ]]; then
    	echo "Permissions for $file are already set to $expected_perms."
    	echo ""
    	return 0
    else
    	return 1
    	fi
}

# Function to create demo directories and files
create_demo_macros() {
    local dir="$1"

    # For directories with permissions
    declare -A dirs
    dirs=( ["0002"]="$dir/directory-0002"
           ["1002"]="$dir/directory-1002"
           ["0755"]="$dir/directory-0755"
           ["1755"]="$dir/directory-1755" )

    for perms in "${!dirs[@]}"; do
        dir_path="${dirs[$perms]}"
        create_directory "$dir_path"
        if ! check_permissions "$dir_path" "$perms"; then
            chmod "$perms" "$dir_path"
        fi
    done

    # For files
    file_path="$dir/file"
    [[ ! -f "$file_path" ]] && touch "$file_path"

    # For executable
    executable_path="$dir/executable"
    if [[ ! -f "$executable_path" ]]; then
        touch "$executable_path"
        chmod +x "$executable_path"
    elif [[ ! -x "$executable_path" ]]; then
        chmod +x "$executable_path"
    fi

    # For symbolic links
    declare -A links
    links=( ["/dev/sda1"]="$dir/link-block_device" 
            ["nonexistent_file"]="$dir/link-nonexistent_file"
            ["file"]="$dir/link-file"
            ["executable"]="$dir/link-executable" )

    for target in "${!links[@]}"; do
        link="${links[$target]}"
        if [[ ! -L "$link" ]] || [[ "$(readlink "$link")" != "$target" ]]; then
            ln -sf "$target" "$link"
        fi
    done

    # For special permissions files
    declare -A special_perms
    special_perms=( ["2000"]="$dir/setgid-2000" ["4000"]="$dir/setuid-4000" )

    for perms in "${!special_perms[@]}"; do
        file_path="${special_perms[$perms]}"
        if [[ ! -f "$file_path" ]]; then
            touch "$file_path"
        fi
        if ! check_permissions "$file_path" "$perms"; then
            chmod "$perms" "$file_path"
        fi
    done
}

# Function to process mime.types
process_mime_types() {
	local dir="$1"
	extension_counter=0
	declare -A unq_extensions
	unq_pri_types=()
	unq_sec_types=()

	# Check if mime.types exists in the given directory
	if [[ ! -f "$dir/mime.types" ]]; then
		divider "-"
		echo "
Error: $dir/mime.types does not exist.

The script created this file, but somebody removed it in the meantime."
		exit 1
	fi

	printf "Processing MIME types... This might take a while\n"
	while IFS= read -r line; do
		# Check if the line contains a /
		if echo "$line" | grep -q "/"; then
			local mime_type=$(echo "$line" | awk '{print $1}')
			local ext=$(echo "$line" | \
				awk '{$1=""; print $0}' | \
				tr -s ' ' | \
				sed 's/^ //')
			local pri_type=$(echo "$mime_type" | cut -d'/' -f1)
			local sec_type=$(echo "$mime_type" | cut -d'/' -f2)

			# Print processing information
			if [[ $verbose == true ]]; then
				echo "Processing MIME type: $mime_type"
			fi

			# Exclude commented lines and inode
			if [[ ${pri_type:0:1} == "#" ]] || \
				[[ ${pri_type:0:5} == "inode" ]]; then
				if [[ $verbose == true ]]; then
					echo "Skipping: $mime_type"
				fi
				continue
			fi

			# Count unique extensions and create files
			# TODO The creation of files must be done in a separate function
			for extension in $ext;
			do
				if [[ ! -f "$dir/$pri_type/$sec_type.$extension" ]];
				then
					mkdir -p "$dir/$pri_type/"
					touch "$dir/$pri_type/$sec_type.$extension"
				fi
				((extension_counter++))
				unq_extensions["$extension"]=1
			done

			# Check if primary type directory exists
			# TODO The creation of directories must be done in a separate function
			if [ ! -d "$dir/$pri_type" ]; then
				create_directory "$dir/$pri_type"
			fi

			# Count unique primary types
			if [[ ! " ${unq_pri_types[@]} " =~ " ${pri_type} " ]];
			then
				unq_pri_types+=("$pri_type")
			fi
		fi
	done < "$dir/mime.types"

	# Count unique secondary types (based on filenames without extensions)
	# TODO The counting of unique secondary types must be done in a separate function
	for pri_type_dir in "$dir"/*; do
		if [ -d "$pri_type_dir" ]; then
			for file in "$pri_type_dir"/*; do
				if [ -f "$file" ]; then
					local file_wo_ext=$(basename "$file")
					file_wo_ext="${file_wo_ext%.*}"  # Remove extension
					if [[ ! " ${unq_sec_types[@]} " =~ " ${file_wo_ext} " ]];
					then
						unq_sec_types+=("$file_wo_ext")
					fi
				fi
			done
		fi
	done

	# Print the counts
	echo "Unique MIME types: ${#unq_pri_types[@]}"
	echo "Unique MIME subtypes: ${#unq_sec_types[@]}"
	echo "Unique extensions: ${extension_counter}"
}

# Function to detect and display the number of supported colors in columns
detect_display_colors() {
	ground="$1"
	
	echo "Detecting terminal colors..."
	num_colors=$(tput colors 2>/dev/null)

	if [[ $? -eq 0 && $num_colors -gt 0 ]]; then
		echo "Your terminal supports ${num_colors} colors."
		echo "Displaying them now..."
		for (( i = 0; i < num_colors; i++ )); do
			# Display the color with its number, without breaking the line.
			echo -en "${s_aes}${ground};${i}m${i}${e_aes}\t"
			
			# If 8 colors have been printed in the current row,
			# move to the next line.
			if (( (i+1) % 8 == 0 )); then
				echo ""
				fi
			done
			# Ensure there's a newline after the colors
			echo ""
		else
			echo "Error: Unable to detect the number of supported colors."
			echo ""
			exit 1
	fi
}

# Function to display a color with optional effects side by side
display_color() {
	local palette="$1" #16-color,256-color,true-color
	local effect="$2"
	local ground="$3"
	
	# Append the formatted color to the line, without breaking the line.
	if [[ "$palette" == 16-color ]];
	then
		# TODO Add support for 16-color palette
		echo -en ""
	elif [[ "$palette" == 256-color ]];
	then
		sequence="${effect};${ground};${code}"
		echo -en "${s_aes}${sequence}m${sequence}${e_aes}\t"
	elif [[ "$palette" == true-color ]];
	then
		# TODO Add support for true-color palette
		echo -en ""
	fi
}

# Function to display ANSI effects
# TODO Add support for other palettes
display_effects() {
	echo "0: Reset/Normal"
	echo "1: Bold/Bright"
	echo ""
	echo "Foreground colors               Background colors"
	echo "------------------------        -------------------------"
	for code in {0..7}; do
		for effect in {0..1}; do
			display_color "256-color" "${effect}" "38;5" "${code}"
			display_color "256-color" "${effect}" "48;5" "${code}"
		done
		echo ""  # Move to the next line after a row is complete
	done
	echo ""
	echo "2: Faint/Dim"
	echo "3: Italic"
	echo ""
	echo "Foreground colors               Background colors"
	echo "------------------------        -------------------------"
	for code in {0..7}; do
		for effect in {2..3}; do
			display_color "256-color" "${effect}" "38;5" "${code}"
			display_color "256-color" "${effect}" "48;5" "${code}"
			done
			echo ""  # Move to the next line after a row is complete
	done
	echo ""
	echo "4: Underline"
	echo "5: Blink"
	echo ""
	echo "Foreground colors               Background colors"
	echo "------------------------        -------------------------"
	for code in {0..7}; do
		for effect in {4..5}; do
			display_color "256-color" "${effect}" "38;5" "${code}"
			display_color "256-color" "${effect}" "48;5" "${code}"
		done
		echo ""  # Move to the next line after a row is complete
	done
	echo ""
	echo "6: Rapid Blink"
	echo "7: Reverse"
	echo ""
	echo "Foreground colors               Background colors"
	echo "------------------------        -------------------------"
	for code in {0..7}; do
		for effect in {6..7}; do
			display_color "256-color" "${effect}" "38;5" "${code}"
			display_color "256-color" "${effect}" "48;5" "${code}"
		done
		echo ""  # Move to the next line after a row is complete
	done
	echo ""
	echo "8: Concealed/Hidden"
	echo "9: Strikethrough"
	echo ""
	echo "Foreground colors               Background colors"
	echo "------------------------        -------------------------"
	for code in {0..7}; do
		for effect in {8..9}; do
			display_color "256-color" "${effect}" "38;5" "${code}"
			display_color "256-color" "${effect}" "48;5" "${code}"
		done
		echo ""  # Move to the next line after a row is complete
	done
	echo ""
}

# Function for the color wizard
color_wizard() {
	# Prompt the user to choose a color and effect from the displayed options
	# TODO Do some input validation
	read -p "Pick a foreground color code (0-255): " u_color_fg < /dev/tty
	read -p "Pick a background color code (0-255): " u_color_bg < /dev/tty
	echo "Add optional effect codes from the range (0-9):"
	echo "    - e.g., 1 for bold, 7 for reverse, 0 or empty for none"
	echo "    - You can pick multiple effects, e.g., 1;7 for bold and reverse"
	read -p "Pick your effects: " u_effects < /dev/tty

	# Form the user sequence
	u_seq="${u_effects};38;5;${u_color_fg};48;5;${u_color_bg}"

	# Display the escape sequence and a text with the chosen color and effect
	echo "The ANSI escape sequence for the above combination is:"
	echo "${s_aes}${u_seq}mThese are your chosen colors and effects!${e_aes}"
	echo ""
}

# Function to declare vars for file types
declare_file_types() {
	declare -g -A file_types=(
	["BLK"]=$'
block devices'
	["CAPABILITY"]=$'
capabilities (linux-specific feature)'
	["CHR"]=$'
character devices'
	["DIR"]=$'
directories'
	["DOOR"]=$'
doors (IPC mechanism on some UNIX systems, notably Solaris)'
	["EXEC"]=$'
executables (files with execute permission set)'
	["FIFO"]=$'
pipes (named pipes/fifos)'
	["FILE"]=$'
regular files'
	["LINK"]=$'
symbolic links'
	["MULTIHARDLINK"]=$'
regular files with multiple hard links'
	["NORMAL"]=$'
global default color'
	["ORPHAN"]=$'
symbolic links pointing to non-existent files'
	["SETGID"]=$'
files or directories with the SETGID bit set'
	["SETUID"]=$'
files with the SETUID bit set'
	["SOCK"]=$'
sockets'
	["OTHER_WRITABLE"]=$'
directories writable to others, without sticky bit'
	["STICKY"]=$'
directories with the sticky bit set, but not other-writable'
	["STICKY_OTHER_WRITABLE"]=$'
directories both other-writable and with sticky bit set'
	)
	declare -g -A file_types_info=(
	["i_BLK"]=$'
Block devices, such as HDDs and SSDs, allow data to be read or written in
blocks.'
	["i_CAPABILITY"]=$'
Capabilities are special attributes in Linux that grant specific privileges to
executables.'
	["i_CHR"]=$'
Character devices communicate with the system by sending or receiving single
characters at a time.'
	["i_DIR"]=$'
"Directories are containers used to organize files and other directories within
a file system.'
	["i_DOOR"]=$'
Doors, primarily found in systems like Solaris, are a unique IPC mechanism for
speedy communication between processes.'
	["i_EXEC"]=$'
Executables are special files that the system can run as programs, identified
by their execute permissions.'
	["i_FIFO"]=$'
FIFOs, or named pipes, are a type of file that allows for inter-process
communication using standard input/output mechanisms.'
	["i_FILE"]=$'
Regular files can contain text, data, or program instructions and are the most
common type of file.'
	["i_LINK"]=$'
Symbolic links are pointers that reference another file or directory by its
path, rather than storing its actual data.'
	["i_MULTIHARDLINK"]=$'
Files with multiple hard links share the same inode, and thus, the same data.
They appear as distinct entries in the file system.'
	["i_NORMAL"]=$'
The global default color setting applies to any file type not explicitly
mentioned.'
	["i_ORPHAN"]=$'
Orphaned symbolic links reference files or directories that no longer exist.'
	["i_SETGID"]=$'
Files or directories with the SETGID bit ensure that newly created files or
subdirectories inherit the group ID of the directory, not that of the creating
process.'
	["i_SETUID"]=$'
Files with the SETUID bit run with the privileges of the file owner, not the
user who executed it.'
	["i_SOCK"]=$'
Sockets are special files that provide a mechanism for processes to communicate,
either locally or over a network.'
	["i_OTHER_WRITABLE"]=$'
Directories writable to others but lacking the sticky bit can be a security risk
as any user can modify their contents.'
	["i_STICKY"]=$'
Directories with the sticky bit set restrict deletion or renaming of files
within. Only the file owner, directory owner, or root can delete or rename a
file.'
	["i_STICKY_OTHER_WRITABLE"]=$'
Directories that are both other-writable and have the sticky bit set can be
shared among users, but with some level of protection against file deletion
by unauthorized users.'
)
	declare -g -A file_types_default=(
	["d_BLK"]="40;33;1"
	["d_CAPABILITY"]="30;41"
	["d_CHR"]="40;33;01"
	["d_DIR"]="01;96"
	["d_DOOR"]="01;95"
	["d_EXEC"]="01;94"
	["d_FIFO"]="40;33"
	["d_FILE"]="0"
	["d_LINK"]="target"
	["d_MULTIHARDLINK"]="00"
	["d_NORMAL"]="0"
	["d_ORPHAN"]="40;31;01"
	["d_SETGID"]="30;43"
	["d_SETUID"]="37;41"
	["d_SOCK"]="01;95"
	["d_OTHER_WRITABLE"]="34;42"
	["d_STICKY"]="37;44"
	["d_STICKY_OTHER_WRITABLE"]="32;44"
	)
}

# Function to generate the file-types colors and effects
generate_file_types() {
	# Get ANSI escape sequence from user
	for key in "${!file_types[@]}"; do
		var_user="u_$key"
		var_default="d_$key"
		prompt_options="
Try:
i - for more information
w - for starting the color wizard
c - for displaying text colors
e - for displaying text effects
q - for quit
"
		while true; do
			echo "${prompt_options}"
			prompt_msg="Enter an ANSI escape sequence for:"
			prompt_for="${file_types[$key]}"
			prompt_default="(thedefault: ${file_types_default[$var_default]}): "
			prompt_full="$prompt_msg"$"$prompt_for"$'\n'"$prompt_default"
			read -p "$prompt_full" u_input
			u_input=${u_input:-${file_types_default[$var_default]}}
			
			# Format checking
			if [[ "${key}" == "LINK" ]];
			then
				if echo "$u_input" | grep -qE "^(target|[0-9;iwqce]*)$";
				then
					echo "" #valid input
				else
					echo "Invalid input. Try again."
					echo ""
					continue
				fi
			else
				if echo "$u_input" | grep -qE "^([0-9;iwqce]*)$";
				then
					echo "" #valid input
				else
					echo "Invalid input. Try again."
					echo ""
					continue
				fi
			fi
			
			case $u_input in
				[Ii]* )
					var_info="i_$key"
					echo "${file_types_info[$var_info]}"
					echo ""
					continue
					;;
				[Ww]* )
					color_wizard
					u_input="${u_seq}"
					;;
				[Cc]* )
					detect_display_colors "38;5"
					continue
					;;
				[Ee]* )
					display_effects
					continue
					;;
				[Qq]* )
					exit 0
			esac
			
			if [[ "$u_input" == "target" ]];
			then
				echo "
Your links will have the colors and effects of the target file."
			else
				echo -e "
${s_aes}${u_input}mThese are your chosen colors and effects for:\
	${file_types[$key]}!${e_aes}"
			fi
			echo ""
			echo ""
			preprompt="Is this the correct colors and effect for:"
			if prompt_ynq "${preprompt}${file_types[$key]}? ";
			then
				declare "$var_user=$u_input" # Dynamically set vars, e.g., u_BLK
				# TODO Replace the ANSI_ESCAPE with the user input in a
				# temporary file, instead of generating the file on the fly with
				# echo and tee.
				echo ""
				echo "Adding to ${of}"
				echo "${key} ${u_input} #\
$(echo "${file_types[$key]}" | tr '\n' ' ')" |\
					tee -a ${of}
				break
			fi
		done
	done
}

# Function to generate a dircolors demo file from the mime-types demo
# directories and files
# TODO Alter this so that the basis for the dircolors file is the mime.types
generate_mime_types_tmp() {
	if="$1"
	of="$2"

	# Ensure the output file exists
	if [[ ! -f $of ]]; then
		touch $of
	fi
	
	# Change to the mime-types directory
	cd $if

	# Loop through subdirectories in the mime-types directory
	for pri_type in */; do
		# Remove trailing slash from directory name
		pri_type=${pri_type%/}
		
		# Loop through files in the subdirectory
		for file in "$pri_type"/*; do
			# Get the file extension
			extension="${file##*.}"
			
			# Get the file name without the extension
			sec_type="${file##*/}"
			# Remove the extension from the file name
			sec_type="${sec_type%.*}"
			
			# Print the desired format
			echo ".$extension ANSI_ESCAPE # $pri_type $sec_type" >> $of
		done
	done

	# Return to the original directory
	cd -
}

# Function to generate an array of extensions, colors, mime_types, and
# mime_subtypes from the dircolors demo file.
generate_mime_types() {
	# Check if the file exists
	if [ ! -f "/tmp/dircolors.demo.tmp" ]; then
		echo "File /tmp/dircolors.demo.tmp does not exist."
		exit 1
	fi

	# Create an array to store extension, color, mime_type, and mime_subtype
	extensions=()

	# Read the file and populate the array
	while IFS= read -r line; do
		# Extract information from each line
		extension=$(echo "$line" | awk '{print $1}')
		color=$(echo "$line" | awk '{print $2}')
		mime_type=$(echo "$line" | awk '{print $4}')
		mime_subtype=$(echo "$line" | awk '{print $5}')

		# Append the data to the array
		echo "Appending $extension $color $mime_type $mime_subtype"
		extensions+=("$extension" "$color" "$mime_type" "$mime_subtype")
	done < "/tmp/dircolors.demo.tmp"
	echo "Array populated."
	echo ""

	while true; do
		echo "Select an option to generate definitions for extensions:"
		echo "1 - Colors and effects for extensions based on MIME types"
		echo "2 - Colors and effects for extensions based on MIME subtypes"
		echo "3 - Colors and effects for extensions one by one"
		echo "q - Quit"

		read -p "Enter your choice: " choice

		case $choice in
			1)
				generate_mime_types_based_on_primary_types
				;;
			2)
				generate_mime_types_based_on_secondary_types
				;;
			3)
				generate_mime_types_based_on_extensions
				;;
			q)
				exit 0
				;;
			*)
				echo "Invalid choice. Please try again."
				;;
		esac
	done
}

# Function to generate mime types based on primary types
generate_mime_types_based_on_primary_types() {
	# Loop through unique primary types and process each element
	for pri_type in "${unq_pri_types[@]}"; do
		echo "Processing primary type: $pri_type"
		while true; do
			echo "Try:"
			echo "i - for more information"
			echo "w - for starting the color wizard"
			echo "c - for displaying text colors"
			echo "e - for displaying text effects"
			echo "q - for quit"
			
			prompt_msg="Enter an ANSI escape sequence for:"
			prompt_for="$pri_type"
			prompt_default="(thedefault: 00;00): "
			prompt_full="$prompt_msg"$'\n'"$prompt_for"$'\n'"$prompt_default"
			
			# Read user input into a variable
			read -p "${prompt_full}" u_input
			u_input=${u_input:-00;00}

			# Format checking
			# TODO Review my options for the format checking
			if echo "$u_input" | grep -qE "^([0-9;iwqce]*)$"; then
				echo "" # valid input
			else
				echo "Invalid input. Try again."
				echo ""
				break  # Exit the inner loop on invalid input
			fi

			case $u_input in
				[Ii]* )
					var_info=""
					echo "Not supported yet"
					echo ""
					echo "Primary type: $pri_type"
					echo "---"
					continue
					;;
				[Ww]* )
					color_wizard
					u_input="${u_seq}"
					;;
				[Cc]* )
					detect_display_colors "38;5"
					continue
					;;
				[Ee]* )
					display_effects
					continue
					;;
				[Qq]* )
					exit 0
			esac
			
			echo -e "
${s_aes}${u_input}mThese are your chosen colors and effects for:\
	${pri_type}${e_aes}"
			echo ""
			echo ""
			preprompt="Is this the correct colors and effect for:"
			if prompt_ynq "${preprompt} ${pri_type}? "; then
				# Replace the ANSI_ESCAPE with the user input
				sed -i "s/ANSI_ESCAPE # ${pri_type}/${u_input} # ${pri_type}/g" /tmp/dircolors.demo.tmp
				break
			fi
		done
	done
}

# Function to generate mime types based on secondary types
generate_mime_types_based_on_secondary_types() {
	# Loop through unique primary types and process each element
	for sec_type in "${unq_sec_types[@]}"; do
		while true; do
			echo "Try:"
			echo "i - for more information"
			echo "w - for starting the color wizard"
			echo "c - for displaying text colors"
			echo "e - for displaying text effects"
			echo "q - for quit"
			
			prompt_msg="Enter an ANSI escape sequence for:"
			prompt_for="$sec_type"
			prompt_default="(thedefault: 00;00): "
			prompt_full="$prompt_msg"$'\n'"$prompt_for"$'\n'"$prompt_default"
			
			# Read user input into a variable
			read -p "${prompt_full}" u_input
			u_input=${u_input:-00;00}

			# Format checking
			# TODO Review my options for the format checking
			if echo "$u_input" | grep -qE "^([0-9;iwqce]*)$"; then
				echo "" # valid input
			else
				echo "Invalid input. Try again."
				echo ""
				break  # Exit the inner loop on invalid input
			fi

			case $u_input in
				[Ii]* )
					var_info=""
					echo "Not supported yet"
					echo ""
					echo "Secondary type: $sec_type"
					echo "---"
					continue
					;;
				[Ww]* )
					color_wizard
					u_input="${u_seq}"
					;;
				[Cc]* )
					detect_display_colors "38;5"
					continue
					;;
				[Ee]* )
					display_effects
					continue
					;;
				[Qq]* )
					exit 0
			esac
			
			echo -e "
${s_aes}${u_input}mThese are your chosen colors and effects for:\
	${sec_type}${e_aes}"
			echo ""
			echo ""
			preprompt="Is this the correct colors and effect for:"
			if prompt_ynq "${preprompt} ${sec_type}? "; then
				# Replace the ANSI_ESCAPE with the user input
				sed -i "/${sec_type}/s/ANSI_ESCAPE/${u_input}/g" /tmp/dircolors.demo.tmp
				break
			fi
		done
	done
}

# Function to generate mime types based on extension
generate_mime_types_based_on_extensions() {
	# Loop through the array and process each element
	for ((i = 0; i < ${#extensions[@]}; i += 4)); do
		extension="${extensions[i]}"
		color="${extensions[i + 1]}"
		mime_type="${extensions[i + 2]}"
		mime_subtype="${extensions[i + 3]}"

		while true; do
			echo "Try:"
			echo "i - for more information"
			echo "w - for starting the color wizard"
			echo "c - for displaying text colors"
			echo "e - for displaying text effects"
			echo "q - for quit"
			
			prompt_msg="Enter an ANSI escape sequence for:"
			prompt_for="$extension"
			prompt_default="(thedefault: 00;00): "
			prompt_full="$prompt_msg"$'\n'"$prompt_for"$'\n'"$prompt_default"
			
			# Read user input into a variable
			read -p "${prompt_full}" u_input
			u_input=${u_input:-00;00}

			# Format checking
			# TODO Review my options for the format checking
			if echo "$u_input" | grep -qE "^([0-9;iwqce]*)$"; then
				echo "" # valid input
			else
				echo "Invalid input. Try again."
				echo ""
				break  # Exit the inner loop on invalid input
			fi

			case $u_input in
				[Ii]* )
					var_info=""
					echo "Not supported yet"
					echo ""
					echo "Extension: $extension"
					echo "MIME Type: $mime_type"
					echo "MIME Subtype: $mime_subtype"
					echo "---"
					continue
					;;
				[Ww]* )
					color_wizard
					u_input="${u_seq}"
					;;
				[Cc]* )
					detect_display_colors "38;5"
					continue
					;;
				[Ee]* )
					display_effects
					continue
					;;
				[Qq]* )
					exit 0
			esac
			
			echo -e "
${s_aes}${u_input}mThese are your chosen colors and effects for:\
	${extension}${e_aes}"
			echo ""
			echo ""
			preprompt="Is this the correct colors and effect for:"
			if prompt_ynq "${preprompt} $extension? "; then
				# Replace the ANSI_ESCAPE with the user input
				sed -i "s/${extension} ANSI_ESCAPE # ${mime_type} ${mime_subtype}/${extension} ${u_input} # ${mime_type} ${mime_subtype}/g" /tmp/dircolors.demo.tmp
				break
			fi
		done
	done
}

# Function to configure dircolors file
configure_dircolors_file() {
	filename="$1"

	found_escape=false

	while IFS= read -r line; do
		# Remove leading and trailing whitespace
		line="${line#"${line%%[![:space:]]*}"}"
		line="${line%"${line##*[![:space:]]}"}"

		# Ignore empty lines
		if [ -z "$line" ]; then
			continue
		fi

		# Ignore lines starting with '#' (comments)
		if [[ $line == \#* ]]; then
			continue
		fi

		# Check if "ANSI_ESCAPE" exists in the line
		if [[ $line == *ANSI_ESCAPE* ]]; then
			found_escape=true
		fi

		# TODO find a way to reduce repeated code
		# If we found the first "ANSI_ESCAPE" line,
		if $found_escape;
		then
			if [[ $line == *MACROS* ]];
			then
				# TODO Ask for colors and effects for MACROS
				local macro=$(echo "$line" | awk '{print $1}')
				local description=$(echo "$line" | awk '{for (i=5; i<=NF; i++) printf "%s ", $i; printf "\n"}')
				while true; do
					prompt_msg="Try:
i - for more information
w - for starting the color wizard
c - for displaying text colors
e - for displaying text effects
q - for quit
Enter an ANSI escape sequence for:"

					prompt_for="$description"
					prompt_default="(thedefault: 00;00): "
					prompt_full="$prompt_msg"$'\n'"$prompt_for"$'\n'"$prompt_default"
			
					# Read user input into a variable
					read -p "${prompt_full}" u_input < /dev/tty
					u_input=${u_input:-00;00}

					# Format checking
					# TODO allow target for links
					if echo "$u_input" | grep -qE "^([0-9;iwqce]*)$";
					then
						echo "" # valid input
					else
						echo "Invalid input. Try again."
					echo ""
						break  # Exit the inner loop on invalid input
					fi

					case $u_input in
						[Ii]* )
							printf "MACRO: $macro\n"
							printf "Description: $description\n"
							continue
							;;
						[Ww]* )
							color_wizard
							u_input="${u_seq}"
							;;
						[Cc]* )
							detect_display_colors "38;5"
							continue
							;;
						[Ee]* )
							display_effects
							continue
							;;
						[Qq]* )
							exit 0
					esac

					# Show the colors and effects to the user and ask for
					# confirmation
					echo -e "
${s_aes}${u_input}mThese are your chosen colors and effects for:\n\
${description}${e_aes}"
					echo ""
					echo ""
					preprompt="Is this the correct colors and effect for:"$'\n'
					if prompt_ynq "${preprompt}${description}? ";
					then
						# Replace the ANSI_ESCAPE with the user input
						sed -i "s/${macro} ANSI_ESCAPE/${macro} ${u_input}/g" "$filename"
					break
					fi
				done

			else
				# TODO Ask for colors and effects for extensions
				local extension=$(echo "$line" | awk '{print $1}')
				local mime_type=$(echo "$line" | awk '{print $4}')
				local mime_subtype=$(echo "$line" | awk '{print $5}')
				while true; do
					prompt_msg="Try:
i - for more information
w - for starting the color wizard
c - for displaying text colors
e - for displaying text effects
q - for quit
Enter an ANSI escape sequence for:"

					prompt_for="$extension"
					prompt_default="(thedefault: 00;00): "
					prompt_full="$prompt_msg"$'\n'"$prompt_for"$'\n'"$prompt_default"
			
					# Read user input into a variable
					read -p "${prompt_full}" u_input < /dev/tty
					u_input=${u_input:-00;00}

					# Format checking
					if echo "$u_input" | grep -qE "^([0-9;iwqce]*)$";
					then
						echo "" # valid input
					else
						echo "Invalid input. Try again."
					echo ""
						break  # Exit the inner loop on invalid input
					fi

					case $u_input in
						[Ii]* )
							printf "Extension: $extension\n"
							printf "MIME type: $mime_type\n"
							printf "MIME subtype: $mime_subtype\n"
							continue
							;;
						[Ww]* )
							color_wizard
							u_input="${u_seq}"
							;;
						[Cc]* )
							detect_display_colors "38;5"
							continue
							;;
						[Ee]* )
							display_effects
							continue
							;;
						[Qq]* )
							exit 0
					esac

					# Show the colors and effects to the user and ask for
					# confirmation
					echo -e "
${s_aes}${u_input}mThese are your chosen colors and effects for:\n\
${extension}${e_aes}"
					echo ""
					echo ""
					preprompt="Is this the correct colors and effect for:"$'\n'
					if prompt_ynq "${preprompt}${extension}? ";
					then
						# Replace the ANSI_ESCAPE with the user input
						sed -i "s/${extension} ANSI_ESCAPE/${extension} ${u_input}/g" "$filename"
					break
					fi
				done
			fi
		fi
	done < "$filename"

	# Print a when we reach EOF
	printf "Reached EOF\n"
}

# Function to generate dircolors template file from etc/mime.types
generate_dircolors_file_template() {
	printf "Generating a dircolors file...\n"

	# Add file type MACROS to dircolors file
	printf "# Generated by thedefault-dircolors-generator ${version}
#
# MACROS for file types, directories, devices and permissions.
#
# Format: MACRO <ANSI escape sequence> # <category> <description>
NORMAL ANSI_ESCAPE # MACROS global default color
FILE ANSI_ESCAPE # MACROS regular files
DIR ANSI_ESCAPE # MACROS directories
EXEC ANSI_ESCAPE # MACROS executables (files with execute permission set)
SETUID ANSI_ESCAPE # MACROS files with the SETUID bit set
SETGID ANSI_ESCAPE # MACROS files or directories with the SETGID bit set
OTHER_WRITABLE ANSI_ESCAPE # MACROS directories writable to others, without sticky bit
STICKY ANSI_ESCAPE # MACROS directories with the sticky bit set, but not other-writable
STICKY_OTHER_WRITABLE ANSI_ESCAPE # MACROS directories both other-writable and with sticky bit set
LINK ANSI_ESCAPE # MACROS symbolic links
ORPHAN ANSI_ESCAPE # MACROS symbolic links pointing to non-existent files
MULTIHARDLINK ANSI_ESCAPE # MACROS regular files with multiple hard links
BLK ANSI_ESCAPE # MACROS block devices
SOCK ANSI_ESCAPE # MACROS sockets
CHR ANSI_ESCAPE # MACROS character devices
FIFO ANSI_ESCAPE # MACROS pipes (named pipes/fifos)
CAPABILITY ANSI_ESCAPE # MACROS capabilities (linux-specific feature)
DOOR ANSI_ESCAPE # MACROS doors (IPC mechanism on some UNIX systems, notably Solaris)
" >> "$dircolors_file"

	# Add MIME types to dircolors file
	printf "#
# Format: <extension> <ANSI escape sequence> # <MIME type> <MIME subtype>
# File extension ANSI_ESCAPE # MIME type MIME subtype
#
" >> "$dircolors_file"

	# We need to get the MIME types from /etc/mime.types
	#
	# Check if /etc/mime.types exists
	if [[ ! -f "/etc/mime.types" ]]; then
		printf "Could not access /etc/mime.types.\n"
		printf "Please ensure the files exists and you have read permissions.\n"
		exit 1
	fi

	# Print a message if verbose is disabled
	printf "Processing MIME types. This might take a while...\n"

	extension_counter=0
	declare -A unq_extensions

	while IFS= read -r line; do
		# Check if the line contains a /
		if echo "$line" | grep -q "/"; then
			local str=$(echo "$line" | awk '{print $1}')
			local ext=$(echo "$line" | \
				awk '{$1=""; print $0}' | \
				tr -s ' ' | \
				sed 's/^ //')
			local mime_type=$(echo "$str" | cut -d'/' -f1)
			local mime_subtype=$(echo "$str" | cut -d'/' -f2)

			# Print processing information
			if [[ $verbose == true ]]; then
				printf "Processing MIME type: $str\n"
			fi

			# Exclude commented lines and inode
			if [[ ${mime_type:0:1} == "#" ]] || \
				[[ ${mime_type:0:5} == "inode" ]]; then
				if [[ $verbose == true ]]; then
					printf "Skipping: $str\n"
				fi
				continue
			fi

			# Add the extension to the dircolors file
			for extension in $ext;
			do
				if [[ ! -f "$mime_types_dir/$mime_type/$mime_subtype.$extension" ]] && \
					[[ ${create_demo_dirs_files} == true ]];
				then
					mkdir -p "$mime_types_dir/$mime_type/"
					touch "$mime_types_dir/$mime_type/$mime_subtype.$extension"
				fi
				printf ".$extension ANSI_ESCAPE # $mime_type $mime_subtype
" >> "$dircolors_file"
				((extension_counter++))
				unq_extensions["$extension"]=1
			done
		fi
	done < "/etc/mime.types"

# Print the counts
	# TODO Handle duplicate extensions
	printf "Extensions found: $extension_counter\n"
	printf "Unique extensions found: ${#unq_extensions[@]}\n"
}

# Function to generate a dircolors file
generate_dircolors_file() {
	dircolors_file="$1"
	printf "Starting generation of a dircolors file...\n"

	# Check if the file exists
	# TODO If the file exists, ask the user if they want to overwrite it
	# TODO If the file exists, ask the user if they want to parse it
	if [ -f "$dircolors_file" ];
	then
		printf "File $dircolors_file exists.\n"

		# Ask the user to overwrite the file or use it
		local prompt="Try:
y - Overwrite the existing file and generate a new dircolors file.
n - Use existing file and start the configurator.
q - Quit the script.
Do you want to overwrite the file? "
		if prompt_ynq "${prompt}";
		then
			printf "Overwriting...\n"
			rm -f "$dircolors_file"
			generate_template=true
		else
			printf "Using existing file...\n"
			generate_template=false
		fi
	else
		generate_template=true
	fi

	if [[ $generate_template == true ]];
	then
		# Create the dircolors file
		touch "$dircolors_file"
	fi

	# Check if the file is readable and writable
	if [ ! -r "$dircolors_file" ]; then
		printf "File $dircolors_file is not readable.\n"
		printf "Please check the permissions of $dircolors_file.\n"
		exit 1
	fi

	# Generate a dircolors file template
	if [[ $generate_template == true ]];
	then
		generate_dircolors_file_template
	fi
	
	# Start the configurator
	if [[ "$dircolors_file" == /tmp/* ]];
	then
		# or exit, continue, etc.
		echo -n ""
	else
		configure_dircolors_file "$dircolors_file"
	fi

	# We are done here
	printf "Finished generation of a dircolors file...\n\n"
}

# Entry point of the script
main() {
	while [[ $# -gt 0 ]]; do
		key="$1"
		case $key in
			--version)
				printf "$version\n"
				exit 0
				;;
			--verbose)
				verbose="true"
				shift # past argument
				;;
			*)    # unknown option
				printf "Unknown option: $1\n"
				exit 1
				;;
		esac
		shift # past argument or value
	done

	# Welcome to thedefault-dircolors-generator
	print_msg "msg_welcome"

	while true; do
		printf "Select an option:\n"
		printf "1 - Generate a dircolors file\n"
		printf "2 - Create a set of directories and files for demonstration\n"
		printf "q - Quit\n"

		read -p "Enter your choice: " choice

		case $choice in
			1)
				create_demo_dirs_files=false
				generate_dircolors_file "dircolors.demo"
				;;
			2)
				create_demo_dirs_files=true
				create_directory "${demo_dir}"
				create_demo_macros "${macros_dir}"
				printf "MACROS demo created\n"
				generate_dircolors_file "/tmp/dircolors.demo"
				printf "MIME demo created\n"
				rm -f "/tmp/dircolors.demo"
				printf "Temporary file removed\n"
				;;
			q)
				exit 0
				;;
			*)
				printf "Invalid choice. Please try again.\n\n"
				;;
		esac
	done

	# Temporary stop execution while working on the code
	exit 0

	# TODO Check if the file exists and offer to parse it

	# Ask the user what's their next action
	local message='
The script will now create a dircolors template file:
"'$(pwd)'/dircolors.template"

y - Creates the dircolors template file.
n - Skips the creation of dircolors template file.
q - Quits this script.'
	local question="
Do you want to proceed?"

	divider "-"
	echo "$message"
	if prompt_ynq "$question";
	then
		local q_create_dircolors_template_file=true
	else
		local q_create_dircolors_template_file=false
	fi

	if [[ ${q_create_dircolors_template_file} == true ]];
	then
		# Create the template file
		echo ""
		process_mime_types "$mime_types_dir"
		echo ""
	else
		# Skip the creation of the template file and proceed to the next
		# question
		app_dir="demo"
		echo ""
	fi

	# Ask the user if what's their next action
	local message='
The script will now generate a dircolors configuration file at:
"'$(pwd)'/dircolors.demo"

y - Starts the dircolors configuration file generator.
n - Skips the dircolors configuration file generation.
q - Quits this script.'
	local question="
Do you want to proceed?"

	divider "-"
	echo "$message"
	if prompt_ynq "$question";
	then
		local generate_dircolors_demo_file=true
	else
		local generate_dircolors_demo_file=false
	fi

	if [[ ${generate_dircolors_demo_file} == true ]];
	then
		if [[ ${create_demo_dirs_files} == true ]];
		then
			local of="dircolors.demo"
			echo ""
			divider "-"
			echo ""
			echo "Adding colors and effects for file types:"
			generate_file_types
			echo ""
			echo "Adding colors and effects for file types completed."
			echo ""
			divider "-"
			echo ""
			echo "Adding colors and effects for mime types:"
			echo ""
			echo "Unique MIME types: ${#unq_pri_types[@]}"
			echo "Unique MIME subtypes: ${#unq_sec_types[@]}"
			echo "Unique extensions: ${extension_counter}"
			echo ""
			echo "Processing MIME types. This might take a while..."
			generate_mime_types_tmp "${mime_types_dir}" "/tmp/dircolors.demo.tmp"
			echo "The temporary file has been created."
			echo ""
			generate_mime_types
		else
			local of="dircolors.demo"
			local prefix="tmp"
			echo ""
			divider "-"
			echo ""
			create_directory "/${prefix}/${app_dir}"
			create_directory "/${prefix}/${file_types_dir}"
			create_demo_file_types "/${prefix}/${file_types_dir}"
			create_directory "/${prefix}/${mime_types_dir}"
			copy_mime_types_etc "/${prefix}/${mime_types_file}"
			process_mime_types "/${prefix}/${mime_types_dir}"
			echo ""
			divider "-"
			echo ""
			echo "Adding colors and effects for file types:"
			generate_file_types
			echo ""
			echo "Adding colors and effects for file types completed."
			echo ""
			divider "-"
			echo ""
			echo "Adding colors and effects for mime types:"
			echo ""
			echo "Unique MIME types: ${#unq_pri_types[@]}"
			echo "Unique MIME subtypes: ${#unq_sec_types[@]}"
			echo "Unique extensions: ${extension_counter}"
			echo ""
			echo "Processing MIME types. This might take a while..."
			generate_mime_types_tmp "/${prefix}/${mime_types_dir}" "/tmp/dircolors.demo.tmp"
			echo "The temporary file has been created."
			echo ""
			generate_mime_types
		fi
	else
		echo "Nothing to be done."
	fi
}

# Execute the main function
# Remove temporary files if they exist
if [[ -d "/tmp/${app_dir}" ]];
then
	rm -rf "/tmp/${app_dir}"
fi
main "$@"


# TODO New flow
# Process /etc/mime.types and generate a template file
# Check if the file exists and avoid processing again if you trust it
# Now we have a file, with ANSI_ESCAPE as the placeholder for the colors and
# effects. We can use sed to replace the placeholder with the user input.
# TODO Parse the file and continue from where the user left off
