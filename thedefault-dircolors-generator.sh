#!/bin/bash

# genDircolors is script for creating a
# primary-mime-type/secondary-mime-type.ext directory structure, along with a
# dircolors file.

# Global variables
version="20230925b"
app_dir="demo"
file_types_dir="${app_dir}/file-types.demo"
mime_types_dir="${app_dir}/mime-types.demo"
mime_types_file="${mime_types_dir}/mime.types"
s_aes="\033["
e_aes="\033[0m"
verbose="false"

# Function to print the welcome message
print_welcome_msg() {
	divider "-"
	echo "
Welcome to thedefault-dircolors-generator!

This script will:
- generate a dircolors configuration file,
- create directories and files with different permissions for demonstration,
- create files with various extensions for demostration.
"
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
		read -p "$message [y/n/q]: " result
		case $result in
			[Yy]* ) return 0;;
			[Nn]* ) return 1;;
			[Qq]* ) exit 0;;
			* ) echo "Please answer yes, no or quit";
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

create_file_types() {
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

# Function to copy mime.types
copy_mime_types() {
	local dest="$1"
	local src="/etc/mime.types"
	local error="
Error: /etc/mime.types does not exist.

This script requires this file to extract the mime types and file extension
information."
	local message="
A mime.types file exist in the current directory:
$(pwd)/mime.types"
	local question="
Overwrite?"

	if [[ ! -f "$src" ]]; then
		echo "$error"
		exit 1
	fi
	
	if [[ -f "$dest" ]]; 
	then
		echo "$message"
		if prompt_ynq "$question";
		then
			rm -rf "$dest"
			cp -f "$src" "$dest"
		else
			echo "
The existing mime.types file will be used."
		fi
	else
		cp -f "$src" "$dest"
	fi
}


process_mime_types() {
	local dir="$1"
	extension_counter=0
	declare -A unq_extensions
	unq_pri_types=()
	unq_sec_types=()
	extension_array=()

	# Check if mime.types exists in the given directory
	if [[ ! -f "$dir/mime.types" ]]; then
		divider "-"
		echo "
Error: $dir/mime.types does not exist.

The script created this file, but somebody removed it in the meantime."
		exit 1
	fi

	echo "Processing mime types. This might take a while..."
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
				echo "Processing mime type: $mime_type"
			fi

			# Exclude commented lines and inode
			if [[ ${pri_type:0:1} == "#" ]] || \
				[[ ${pri_type:0:5} == "inode" ]]; then
				if [[ $verbose == true ]]; then
					echo "Skipping: $mime_type"
				fi
				continue
			fi

			# Count unique extensions
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

	# Count unique extensions and store them in the extension_array
	for pri_type_dir in "$dir"/*; do
		if [ -d "$pri_type_dir" ]; then
			for file in "$pri_type_dir"/*; do
				if [ -f "$file" ]; then
					local file_wo_ext=$(basename "$file")
					local extension="${file_wo_ext##*.}"  # Extract extension
					file_wo_ext="${file_wo_ext%.*}"  # Remove extension
					
					if [[ ! " ${unq_sec_types[@]} " =~ " ${file_wo_ext} " ]];
					then
						unq_sec_types+=("$file_wo_ext")
					fi
					
					if [[ ! " ${extension_array[@]} " =~ " ${extension} " ]];
					then
						extension_array+=("$extension")
						((extension_counter++))
					fi
				fi
			done
		fi
	done

	# Print the counts
	echo "Unique primary mime types: ${#unq_pri_types[@]}"
	echo "Unique secondary mime types: ${#unq_sec_types[@]}"
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
		# add support
		echo -en ""
	elif [[ "$palette" == 256-color ]];
	then
		sequence="${effect};${ground};${code}"
		echo -en "${s_aes}${sequence}m${sequence}${e_aes}\t"
	elif [[ "$palette" == true-color ]];
	then
		# add support
		echo -en ""
	fi
}

# Function to display ANSI effects
# TODO add support for other palettes
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
	read -p "Pick a foreground color code (0-255): " u_color_fg
	read -p "Pick a background color code (0-255): " u_color_bg
	echo "Add optional effect codes from the range (0-9):"
	echo "    - e.g., 1 for bold, 7 for reverse, 0 or empty for none"
	echo "    - You can pick multiple effects, e.g., 1;7 for bold and reverse"
	read -p "Pick your effects: " u_effects

	# Form the user sequence
	u_seq="${u_effects};38;5;${u_color_fg};48;5;${u_color_bg}"

	# Display the escape sequence and a text with the chosen color and effect
	echo "The ANSI escape sequence for the above combination is:"
	echo "${s_aes}${u_seq}mThese are your chosen colors and effects!${e_aes}"
	echo ""
}

# Function to generate the file-types colors and effects
generate_file_types() {
	# Get ANSI escape sequence from user
	declare -A file_types=(
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
	declare -A file_types_info=(
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
	declare -A file_types_default=(
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
			if echo "$u_input" | grep -qE "^(target|[0-9;iwqce]*)$";
			then
				echo "" #valid input
			else
				echo "Invalid input. Try again."
				echo ""
				continue
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
generate_mime_types() {
	while true; do
		echo "Select an option to generate mime types:"
		echo "1 - Generate mime types based on primary mime types"
		echo "2 - Generate mime types based on secondary mime types"
		echo "3 - Generate mime types based on extensions"
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

generate_mime_types_based_on_primary_types() {
	# Generate mime types based on unique primary types
	for primary_type in "${unq_pri_types[@]}"; do
		# Customize the mime type generation accordingly
		echo "$primary_type"
		# Or you can write to a file as needed.
	done
}

generate_mime_types_based_on_secondary_types() {
	# Generate mime types based on unique secondary types
	for secondary_type in "${unq_sec_types[@]}"; do
		# Customize the mime type generation accordingly
		echo "$secondary_type"
		# Or you can write to a file as needed.
	done
}

generate_mime_types_based_on_extensions() {
	# Generate mime types based on unique extensions
	for extension in "${extension_array[@]}"; do
		# Customize the mime type generation accordingly
		echo "$extension"
		# Or you can write to a file as needed.
	done
}

# Entry point of the script
main() {
	while [[ $# -gt 0 ]]; do
		key="$1"
		case $key in
			--version)
				echo "$version"
				exit 0
				;;
			--verbose)
				verbose="true"
				shift # past argument
				;;
			*)    # unknown option
				echo "Unknown option: $1"
				exit 1
				;;
		esac
		shift # past argument or value
	done

	# Welcome to thedefault-dircolors-generator
	print_welcome_msg

	# Ask the user if what's their next action
	local message='
The script will now create demonstration directories and files in:
"'$(pwd)'/'${app_dir}'/"

y - Creates demostration directories and files.
n - Skips the creation of demonstration directories and files.
q - Quits this script.'
	local question="
Do you want to proceed?"

	divider "-"
	echo "$message"
	if prompt_ynq "$question";
	then
		local create_demo_dirs_files=true
	else
		local create_demo_dirs_files=false
	fi

	if [[ ${create_demo_dirs_files} == true ]];
	then
		echo ""
		create_directory "$app_dir"
		create_directory "$file_types_dir"
		create_file_types "$file_types_dir"
		create_directory "$mime_types_dir"
		copy_mime_types "$mime_types_file"
		process_mime_types "$mime_types_dir"
		echo ""
	else
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
			echo "Unique primary mime types: ${#unq_pri_types[@]}"
			echo "Unique secondary mime types: ${#unq_sec_types[@]}"
			echo "Unique extensions: ${extension_counter}"
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
			create_file_types "/${prefix}/${file_types_dir}"
			create_directory "/${prefix}/${mime_types_dir}"
			copy_mime_types "/${prefix}/${mime_types_file}"
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
			echo "Unique primary mime types: ${#unq_pri_types[@]}"
			echo "Unique secondary mime types: ${#unq_sec_types[@]}"
			echo "Unique extensions: ${extension_counter}"
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

