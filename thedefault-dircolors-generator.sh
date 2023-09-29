#!/bin/bash
#
#TODO Remove unnecessary code

# Description of the script:
# genDircolors is script for creating a
# primary-mime-type/secondary-mime-type.ext directory structure, along with a
# dircolors file.

# Global variables
help=""
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

# Function to create or overwrite a directory
create_directory() {
	local dir="$1"
	local message="
The script will use the existing directory and it will not delete or overwrite
existing files, however, it may alter their permissions in some cases.
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
    	printf "Permissions for $file are already set to $expected_perms."
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
			# TODO Add support for parsing the existing file
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
			--help)
				# TODO Add help message
				printf "$help\n"
				exit 0
				;;
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
				printf "MACROS demonstration directories and files created\n"
				generate_dircolors_file "/tmp/dircolors.demo"
				printf "MIME demonstration directories and files created\n"
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
}

# Execute the main function
main "$@"
