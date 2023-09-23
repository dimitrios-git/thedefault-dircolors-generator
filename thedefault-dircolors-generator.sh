#!/bin/bash

# genDircolors is script for creating a
# primary-mime-type/secondary-mime-type.ext directory structure, along with a
# dircolors file.

version="20230922b"

# This allows for skipping in the script's flow
skip=false

# Function to print the welcome message
welcome_msg() {
	echo ""
	echo "Welcome to thedefault-dircolors-generator!"
	echo "------------------------------------------"
	echo ""
	echo "This script will generate a dircolors configuration file, along with"
	echo "directories and files with different permissions to demonstrate the"
	echo "configuration you created."
	echo ""
}

# Function to prompt user for yes/no
prompt_yes_no() {
	local message="$1"
	local result
	
	while true; do
		read -p "$message [y/n/q]: " result
		case $result in
			[Yy]* ) return 0;;  # Return 0 for 'yes'
			[Nn]* ) return 1;;  # Return 1 for 'no'
			[Qq]* ) exit 0;; # Exit 0 for 'quit'
			* ) echo "Please answer yes, no or quit";;
		esac
	done
}

# Function to create or replace a directory
create_or_replace_directory() {
	local dir="$1"
	
	if [[ -d "$dir" ]]; then
		if prompt_yes_no "A $dir directory already exists. Replace?"; then
			rm -rf "$dir" && mkdir -p "$dir"
		else
			echo "The script will use the existing directory and it will not"
			echo "delete existing files."
			echo ""
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

create_demo_dirs_files() {
    local dir="$1"

    # For directories with permissions
    declare -A dirs
    dirs=( ["0002"]="$dir/directory-0002" 
           ["1002"]="$dir/directory-1002" 
           ["0755"]="$dir/directory-0755" 
           ["1755"]="$dir/directory-1755" )

    for perms in "${!dirs[@]}"; do
        dir_path="${dirs[$perms]}"
        create_or_replace_directory "$dir_path"
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
            ["executable"]="$dir/executable" )

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

	if [[ ! -f "$src" ]]; then
		echo "Error: /etc/mime.types does not exist."
		echo ""
		exit 1
	fi
	
	if [[ -f "$dest" ]]; then
		if prompt_yes_no "A mime.types file already exists. Overwrite?"; then
			cp -f "$src" "$dest"
		else
			echo "The existing mime.types file will be used."
			echo ""
		fi
	else
		cp -f "$src" "$dest"
	fi
}

# Function to process the mime.types file and generate directories and files.
process_mime_types() {
	local dir="$1"
	
	# Check if mime.types exists in the given directory
	if [[ ! -f "$dir/mime.types" ]]; then
		echo "Error: $dir/mime.types does not exist."
		echo ""
		exit 1
	fi
	
	while IFS= read -r line; do
		# check if line contains a /
		if echo "$line" | grep -q "/"; then
			local mime_type=$(echo "$line" | awk '{print $1}')
			local ext=$(echo "$line" | \
				awk '{$1=""; print $0}' | \
				tr -s ' ' | \
				sed 's/^ //')
			local primary_type=$(echo "$mime_type" | cut -d'/' -f1)
			local secondary_type=$(echo "$mime_type" | cut -d'/' -f2)
		
			# TODO show this only in verbose mode
			echo "Processing mime type: $mime_type"
			
			# exclude commented lines and inode
			if [[ ${primary_type:0:1} == "#" ]] || \
				[[ ${primary_type:0:5} == "inode" ]]; then
							echo "Skipping: $mime_type"
							continue
			fi
			
			if [ ! -d "$dir/$primary_type" ]; then
				create_or_replace_directory "$dir/$primary_type"
			fi
			
			for extension in $ext; do
				if [[ ! -f "$dir/$primary_type/$secondary_type.$extension" ]];
				then
					touch "$dir/$primary_type/$secondary_type.$extension"
				fi
			done
		fi
	done < "$dir/mime.types"
}

# Function to print the welcome message
ansi_intro() {
	echo "ANSI Colors and Effects"
	echo "-----------------------"
	echo "The American National Standards Institute (ANSI) escape sequences"
	echo "define a way to embed control sequences in text streams. These"
	echo "sequences are used, among other things, to control color and"
	echo "formatting in terminal outputs. The sequences can control various"
	echo "properties like text color, background color, and text effects."
	echo ""
}
# Start (s) and End (e) ANSI Escape Sequences (aes)
s_aes="\033["
e_aes="\033[0m"

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
	read -p "Pick a foreground color code from the range (0-255): " u_color_fg
	read -p "Pick a background color code from the range (0-255): " u_color_bg
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
	["BLK"]$'block devices'
	["CAPABILITY"]$'capabilities (linux-specific feature)'
	["CHR"]$'character devices'
	["DIR"]$'directories'
	["DOOR"]$'doors (IPC mechanism on some UNIX systems, notably Solaris)'
	["EXEC"]$'executables (files with execute permission set)'
	["FIFO"]$'pipes (named pipes/fifos)'
	["FILE"]$'regular files'
	["LINK"]$'symbolic links'
	["MULTIHARDLINK"]$'regular files with multiple hard links'
	["NORMAL"]$'global default color'
	["ORPHAN"]$'symbolic links pointing to non-existent files'
	["SETGID"]$'files or directories with the SETGID bit set'
	["SETUID"]$'files with the SETUID bit set'
	["SOCK"]$'sockets'
	["OTHER_WRITABLE"]$'directories writable to others, without sticky bit'
	["STICKY"]$'directories with the sticky bit set, but not other-writable'
	["STICKY_OTHER_WRITABLE"]$'
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
	["i_SETUID"]=$'Files with the SETUID bit run with the privileges of the
file owner, not the user who executed it.'
	["i_SOCK"]=$'Sockets are special files that provide a mechanism for
processes to communicate, either locally or over a network.'
	["i_OTHER_WRITABLE"]=$'Directories writable to others but lacking the sticky
bit can be a security risk as any user can modify their contents.'
	["i_STICKY"]=$'Directories with the sticky bit set restrict deletion or
renaming of files within. Only the file owner, directory owner, or root can
delete or rename a file.'
	["i_STICKY_OTHER_WRITABLE"]=$'Directories that are both other-writable and
have the sticky bit set can be shared among users, but with some level of
protection against file deletion by unauthorized users.'
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
		while true; do
			echo "Try: i for info | w for color wizard | q for quit"
			prompt_msg="Enter an ANSI escape sequence"
			prompt_for="for ${file_types[$key]}"
			prompt_default="(thedefault: ${file_types_default[$var_default]}): "
			prompt_full="$prompt_msg"$'\n'"$prompt_for"$'\n'"$prompt_default"
			read -p "$prompt_full" u_input
			u_input=${u_input:-${file_types_default[$var_default]}}
			
			# Format checking
			if echo "$u_input" | grep -qE "^(target|[0-9;iwq]*)$";
			then
				echo "valid input"
				echo ""
			else
				echo "invalid input"
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
				[Qq]* )
					exit 0
			esac
			
			if [[ "$u_input" == "target" ]];
			then
				echo "Your links will have the colors and effects of the"
				echo "target file."
			else
				echo -e "${s_aes}${u_input}mThese are your chosen colors"\
					"and effects\nfor ${file_types[$key]}!${e_aes}"
			fi
			echo ""
			echo "Is this the correct colors and effect"
			if prompt_yes_no "for ${file_types[$key]}? ";
			then
				declare "$var_user=$u_input" # Dynamically set vars, e.g., u_BLK
				echo "Adding to ${of}"
				echo "$key $u_input # ${file_types[$key]}" | tee -a ${of}
				echo ""
				break
			fi
		done
	done
}

# Function to generate mime-type colors and effects
generate_mime_types() {
	# TODO this copy/paste from above! It needs editing.
	# the mime_types[@] does not exist yet.
	for key in "${!mime_types[@]}"; do
		var_user="u_$key"
		var_default="d_$key"
		while true; do
			echo "Try: i for info | w for color wizard | q for quit"
			prompt_msg="Enter an ANSI escape sequence"
			prompt_for="for ${file_types[$key]}"
			prompt_default="(thedefault: ${file_types_default[$var_default]}): "
			prompt_full="$prompt_msg"$'\n'"$prompt_for"$'\n'"$prompt_default"
			read -p "$prompt_full" u_input
			u_input=${u_input:-${file_types_default[$var_default]}}
			
			# Format checking
			if echo "$u_input" | grep -qE "^(target|[0-9;iwq]*)$";
			then
				echo "valid input"
				echo ""
			else
				echo "invalid input"
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
				[Qq]* )
					exit 0
			esac
			
			if [[ "$u_input" == "target" ]];
			then
				echo "Your links will have the colors and effects of the"
				echo "target file."
			else
				echo -e "${s_aes}${u_input}mThese are your chosen colors"\
					"and effects\nfor ${file_types[$key]}!${e_aes}"
			fi
			echo ""
			echo "Is this the correct colors and effect"
			if prompt_yes_no "for ${file_types[$key]}? ";
			then
				declare "$var_user=$u_input" # Dynamically set vars, e.g., u_BLK
				echo "Adding to ${of}"
				echo "$key $u_input # ${file_types[$key]}" | tee -a ${of}
				echo ""
				break
			fi
		done
	done
}

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
			--dry-run)
				dry_run=true
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
	welcome_msg

	# Skip the next skippable if dry run mode is on.
	# id: S000
	if [[ $dry_run == true ]];
	then
		skip=true
		file_dir="/tmp/file-types.demo"
		mime_dir="/tmp/mime-types.demo"
	fi

	if [[ $skip == false ]]; then
	# Prompt user to start creating the demo dirs and files
	echo "The script will now create the directories and files for demostration"
	echo "purposes in $(pwd)"
	echo ""
	if prompt_yes_no "Do you want to proceed?";
	then
		skip=false
	else
		skip=true
		file_dir="/tmp/file-types.demo"
		mime_dir="/tmp/mime-types.demo"
	fi

	# id: S000
	fi

	# Skipping demo dirs and files creation - id: Q000
	if [[ $skip == false ]];
	then
		mime_dir="mime-types.demo"
		file_dir="file-types.demo"
	else
		mime_dir="/tmp/mime-types.demo"
		file_dir="/tmp/file-types.demo"
	fi

	# Create the demonstration directories
	create_or_replace_directory "$mime_dir"
	create_or_replace_directory "$file_dir"

	# Generate the demo files and directories, and set permissions
	create_demo_dirs_files "$file_dir"

	# Copy the mime.types from host
    copy_mime_types "$mime_dir/mime.types"

	# Process the mime.types file and generate directories and files
	process_mime_types "$mime_dir"

	# Check for dry-run mode
	if [[ $dry_run == true ]]; then
		of="/tmp/dircolors.demo"
		touch ${of}
		question="The script is running in dry run mode. Continue? "
	else
		of="dircolors.demo"
		question="A dircolors.demo file already exists. Overwrite? "
	fi

	# Generate dircolors file
	while true; do
		# Check if the output file already exists
		if [ -f "$of" ]; then
			if prompt_yes_no "${question}";
			then
				rm -f "$of"
				break  # Exit the loop as the user chose to overwrite
			else
				echo "The script will now continue in dry run mode."
				echo "Your dircolors file will not be saved!"
				echo ""
				
				# Ask the user for confirmation to continue in dry run mode
				if prompt_yes_no "Are you sure?"; then
					# The user confirmed the dry run mode;
					dry_run=true
					of="/tmp/dircolors.demo"
					touch ${of}
					question="The script is running in dry run mode. Continue? "
					break  # Exit the loop as the user has confirmed
				else
					# Go back to the start of the loop and ask again
					continue
				fi
			fi
		else
			# If the file doesn't exist, just break out of the loop and continue
			break
		fi
	done

	# Prompt user to start ANSI education
	echo "Dircolors use ANSI escape sequences to colorize and format text."
	if prompt_yes_no "Do you know what's an ANSI escape sequence? ";
	then
		skip=true
	else
		skip=false
	fi

	# Skipping ANSI color introduction - id: Q001
	if [[ $skip == false ]]; then

	# Display ANSI Introduction
	ansi_intro

	# Ask the user if they are interested in seing their terminal colors
	if prompt_yes_no "Do you want to see what colors your terminal supports?";
	then
		detect_display_colors "38;5"
	fi

	# Ask the user if they are interested in seing their background colors
	echo "Your terminal can show these colors as background colors as well."
	if prompt_yes_no "Do you want to see them?";
	then
		detect_display_colors "48;5"
	fi

	# Ask the user if they are interested in seing the effect ANSI supports
	echo "ANSI escape sequences can be used to display various text effects."
	echo "If your terminal emulator does not support a particular effect, it"
	echo "will display normal text instead."
	if prompt_yes_no "Do you want to see the effects?";
	then
		display_effects
	fi

	# Ask the user if they are interested in creating their own color/effect
	# combination
	if prompt_yes_no "Do you want to create your own color/effect combination?";
	then
		color_wizard
		echo -e "${s_aes}${u_seq}mThese are your chosen colors"\
			"and effects!${e_aes}"
	fi

	# Skipping ANSI color introduction - id: Q001
	fi

	# Generate the dircolors.demo file
	echo "The script will now start generating the dircolors.demo file."
	if [[ $of == "/tmp/dircolors.demo" ]];
	then
		echo "thedefault-dircolors-generator is running in dry mode."
		echo "Your dircolors configuration file will not be saved!"
		echo ""
	fi
	
	# Generate file-types colors and effects
	generate_file_types
	echo "File types colors and effects generated successfully."
	echo ""

	# Generate mime-types colors and effects
	if [[ $dry_run == true ]];
	then
		mime_dir="/tmp/mime-types.demo"
	fi
	
	# TODO Implement palettes
	# TODO Implement palette viewer
	# TODO Implement primary MIME type coloring mode
	# TODO Implement insane coloring mode (by extension)
	# TODO Implement custom colors
	# TODO Implement a generate_mime_types function using generate_file_types as
	# a model

	# Traverse the directories
	for entry in $mime_dir/*; do
		echo "Checking entry: $entry"
	
		if [ -d "$entry" ]; then
			# Run the printColors.sh script
			echo "Here I need to change the code"
			echo "Exiting..."
			exit 0
			./printColors.sh
		
			# Prompt user for color input
			valid_colors=(
				30 31 32 33 34 35 36 37
				40 41 42 43 44 45 46 47
				90 91 92 93 94 95 96 97
				100 101 102 103 104 105 106 107
			)

			while true; do
				read -p "Enter the 2 or 3-digit color code for $entry: " user_color
			
				if [[ " ${valid_colors[@]} " =~ " ${user_color} " ]]; then
					break
				else
					echo "Invalid input. Please enter a valid color code."
				fi
			done
		
			# Write the directory name as a comment
			printf "# $entry\n" >> "$of"
	
			# List all the file extensions in the directory with the color
			for file in "$entry"/*; do
				if [ -f "$file" ]; then  # Ensure it's a file
					ext=".${file##*.}"   # Extract the file extension
					
					# Extracting the mime type from the directory structure
					primary_mime=$(basename "$(dirname "$file")")
					secondary_mime=$(basename "$file" ".$ext")
					full_mime="$primary_mime/$secondary_mime"
					echo "Adding extension: $ext for MIME type: $full_mime"
					printf "$ext 00;$user_color # $full_mime\n" >> "$of"
				fi
			done
		fi
	done

    # Install for local user
    if prompt_yes_no "Would you like to install the generated dircolors?"; then
    	if [[ -f "$HOME/.dircolors" ]]; then
    		if prompt_yes_no "A dircolors file already exists. Overwrite?"; then
    			rm -f "$HOME/.dircolors"
    			cp -f $of $HOME/.dircolors
    		else
    			echo "Exiting..."
    			exit 0
    		fi
    	else
    			cp -f $of $HOME/.dircolors
    	fi
    fi

    exit 0
}

# Execute the main function
main "$@"

