#!/bin/bash
GREEN='\e[1;32m'
PURPLE='\e[1;35m'
RED='\e[1;31m'
WHITE='\e[1;37m'
RESET='\033[0m'
VALGRIND="valgrind --leak-check=full --track-fds=yes --show-leak-kinds=all --log-file=.julesmemlog"

run_error()
{
	local test_desc=$1
	shift
	> $juleserror
	> .julesmemlog
	timeout 10 ${VALGRIND} ./pipex $@ 1> $julesout 2> $juleserror
	pipex_exit=$?
	grep --text "FILE DESCRIPTORS:" .julesmemlog  | sed 's/==[0-9]\+== //g' > $julesvalcheck
	grep --text "ERROR SUMMARY:" .julesmemlog  | sed 's/==[0-9]\+== //g' >> $julesvalcheck
	open=$(grep "FILE DESCRIPTORS:" $julesvalcheck | grep -oP '\d+(?= open)' | head -n 1)
	std=$(grep "FILE DESCRIPTORS:" $julesvalcheck | grep -oP '(?<=\()(\d+)(?= std)' | head -n 1)
	open=$((open - 1))
	if [ $pipex_exit -eq 124 ]; then
		echo -n "❌"
		echo -e "$test_desc: Pipex timed out\n" >> pipex_trace
	elif [ ! -s $juleserror ] && [ ! -s $julesout ]; then
		echo -n "❌"
		echo -e "$test_desc: No error message found\n" >> pipex_trace
	elif grep -q "ERROR SUMMARY: [^0]" $julesvalcheck; then
		echo -n "❌"
		echo -e "$test_desc: Memory leak detected\n" >> pipex_trace
	elif ! [ $open -eq $std ]; then
		echo -n "❌"
		echo -e "$test_desc: Non standard file descriptor open" >> pipex_trace
		echo -e "Open: $open | Standard: $std\n" >> pipex_trace
	else
		echo -n "✅"
	fi
}

run_pipex_no_path()
{
	> $julesbashout
	> .julesmemlog
	> $julesdiff
	> $julesvalcheck
	> "$outfile"
	local test_desc=$1
	local infile=$2
	local cmd1=$3
	local cmd2=$4
	local outfile=$5
	shift
	set -- $cmd1
	local split1=$1
	local arg1=$2
	set -- $cmd2
	local split2=$1
	local arg2=$2
	/bin/timeout 15 /bin/${VALGRIND} ./pipex "$infile" "$cmd1" "$cmd2" "$outfile" 2> /dev/null 1> /dev/null
	pipex_exit=$?
	if [ $pipex_exit -eq 124 ]; then
		/bin/echo -n "❌"
		/bin/echo -e "$test_desc: Pipex timed out\n" >> pipex_trace
		return
	fi
	< ""$infile"" $split1 $arg1 | $split2 $arg2 > $julesbashout 2> /dev/null
	bash_exit=$?
	/bin/grep --text "FILE DESCRIPTORS:" .julesmemlog  | /bin/sed 's/==[0-9]\+== //g' > $julesvalcheck
	/bin/grep --text "ERROR SUMMARY:" .julesmemlog  | /bin/sed 's/==[0-9]\+== //g' >> $julesvalcheck
	open=$(/bin/grep "FILE DESCRIPTORS:" $julesvalcheck | /bin/grep -oP '\d+(?= open)' | /bin/head -n 1)
	std=$(/bin/grep "FILE DESCRIPTORS:" $julesvalcheck | /bin/grep -oP '(?<=\()(\d+)(?= std)' | /bin/head -n 1)
	open=$((open - 1))
	if ! /bin/diff $julesbashout "$outfile" > $julesdiff; then
		/bin/echo -n "❌"
		/bin/echo -e "$test_desc: Output incorrect\n" >> pipex_trace
		/bin/cat $julesdiff >> pipex_trace
	elif [ "$pipex_exit" -ne "$bash_exit" ]; then
		echo -n "❌"
		echo -e "$test_desc: Exit code incorrect" >> pipex_trace
		echo -e "Pipex exit code: $pipex_exit\nBash exit code: $bash_exit\n" >> pipex_trace
	elif grep -q "ERROR SUMMARY: [^0]" $julesvalcheck; then
		/bin/echo -n "❌"
		/bin/echo -e "$test_desc: Memory leak detected\n" >> pipex_trace
	elif ! [ $open -eq $std ]; then
		/bin/echo -n "❌"
		/bin/echo -e "$test_desc: Non standard file descriptor open" >> pipex_trace
		/bin/echo -e "Open: $open | Standard: $std\n" >> pipex_trace
	else
		/bin/echo -n "✅"
	fi
}

run_pipex()
{
	exec 2>/dev/null
	> "$julesbashout"
	> ".julesmemlog"
	> "$julesdiff"
	> "$julesvalcheck"
	local test_desc=$1
	local infile=$2
	local cmd1=$3
	local cmd2=$4
	local outfile=$5
	shift
	set -- $cmd1
	local split1=$1
	local arg1=$2
	set -- $cmd2
	local split2=$1
	local arg2=$2
	> "$outfile"
	timeout 15 ${VALGRIND} ./pipex "$infile" "$cmd1" "$cmd2" "$outfile"
	pipex_exit=$?
	if [ $pipex_exit -eq 124 ]; then
		echo -n "❌"
		echo -e "$test_desc: Pipex timed out\n" >> pipex_trace
		return
	fi
	< "$infile" $split1 $arg1 | $split2 $arg2 > $julesbashout
	bash_exit=$?
	grep --text "FILE DESCRIPTORS:" .julesmemlog  | sed 's/==[0-9]\+== //g' > $julesvalcheck
	grep --text "ERROR SUMMARY:" .julesmemlog  | sed 's/==[0-9]\+== //g' >> $julesvalcheck
	open=$(grep "FILE DESCRIPTORS:" $julesvalcheck | grep -oP '\d+(?= open)' | head -n 1)
	std=$(grep "FILE DESCRIPTORS:" $julesvalcheck | grep -oP '(?<=\()(\d+)(?= std)' | head -n 1)
	open=$((open - 1))
	if ! diff $julesbashout "$outfile" > $julesdiff; then
		echo -n "❌"
		echo -e "$test_desc: Output incorrect\n" >> pipex_trace
		cat $julesdiff >> pipex_trace
	elif [ "$pipex_exit" -ne "$bash_exit" ]; then
		echo -n "❌"
		echo -e "$test_desc: Exit code incorrect" >> pipex_trace
		echo -e "Pipex exit code: $pipex_exit\nBash exit code: $bash_exit\n" >> pipex_trace
	elif grep -q "ERROR SUMMARY: [^0]" $julesvalcheck; then
		echo -n "❌"
		echo -e "$test_desc: Memory leak detected\n" >> pipex_trace
	elif ! [ $open -eq $std ]; then
		echo -n "❌"
		echo -e "$test_desc: Non standard file descriptor open" >> pipex_trace
		echo -e "Open: $open | Standard: $std\n" >> pipex_trace
	else
		echo -n "✅"
	fi
}

run_permissions()
{
	> $julesbashout
	> .julesmemlog
	> $julesdiff
	> $julesvalcheck
	local test_desc=$1
	local infile=$2
	local cmd1=$3
	local cmd2=$4
	local outfile=$5
	shift
	set -- $cmd1
	local split1=$1
	local arg1=$2
	set -- $cmd2
	local split2=$1
	local arg2=$2
	timeout 15 ${VALGRIND} ./pipex "$infile" "$cmd1" "$cmd2" "$outfile" 2> /dev/null 1> /dev/null
	pipex_exit=$?
	if [ $pipex_exit -eq 124 ]; then
		echo -n "❌"
		echo -e "$test_desc: Pipex timed out\n" >> pipex_trace
		return
	fi
	< "$infile" $split1 $arg1 | $split2 $arg2 > $julesbashout 2> /dev/null
	bash_exit=$?
	chmod 644 "$infile"
	chmod 644 "$outfile"
	chmod 644 $julesbashout
	grep --text "FILE DESCRIPTORS:" .julesmemlog  | sed 's/==[0-9]\+== //g' > $julesvalcheck
	grep --text "ERROR SUMMARY:" .julesmemlog  | sed 's/==[0-9]\+== //g' >> $julesvalcheck
	open=$(grep "FILE DESCRIPTORS:" $julesvalcheck | grep -oP '\d+(?= open)' | head -n 1)
	std=$(grep "FILE DESCRIPTORS:" $julesvalcheck | grep -oP '(?<=\()(\d+)(?= std)' | head -n 1)
	open=$((open - 1))
	if ! diff $julesbashout "$outfile" > $julesdiff; then
		echo -n "❌"
		echo -e "$test_desc: Output incorrect\n" >> pipex_trace
		cat $julesdiff >> pipex_trace
	elif [ "$pipex_exit" -ne "$bash_exit" ]; then
		echo -n "❌"
		echo -e "$test_desc: Exit code incorrect" >> pipex_trace
		echo -e "Pipex exit code: $pipex_exit\nBash exit code: $bash_exit\n" >> pipex_trace
	elif grep -q "ERROR SUMMARY: [^0]" $julesvalcheck; then
		echo -n "❌"
		echo -e "$test_desc: Memory leak detected\n" >> pipex_trace
	elif ! [ $open -eq $std ]; then
		echo -n "❌"
		echo -e "$test_desc: Non standard file descriptor open" >> pipex_trace
		echo -e "Open: $open | Standard: $std\n" >> pipex_trace
	else
		echo -n "✅"
	fi
}

run_special_case()
{
	> .julesmemlog
	> $julesdiff
	> $julesvalcheck
	> "$outfile"
	local test_desc=$1
	local infile=$2
	local cmd1=$3
	local cmd2=$4
	local outfile=$5
	shift
	set -- $cmd1
	local split1=$1
	local arg1=$2
	set -- $cmd2
	local split2=$1
	local arg2=$2
	timeout 15 ${VALGRIND} ./pipex "$infile" "$cmd1" "$cmd2" "$outfile" 2> /dev/null 1> /dev/null
	pipex_exit=$?
	if [ $pipex_exit -eq 124 ]; then
		echo -n "❌"
		echo -e "$test_desc: Pipex timed out\n" >> pipex_trace
		return
	fi
	< "$infile" $split1 $arg1 | $split2 $arg2 > $julesbashout 2> /dev/null
	bash_exit=$?
	grep --text "FILE DESCRIPTORS:" .julesmemlog  | sed 's/==[0-9]\+== //g' > $julesvalcheck
	grep --text "ERROR SUMMARY:" .julesmemlog  | sed 's/==[0-9]\+== //g' >> $julesvalcheck
	open=$(grep "FILE DESCRIPTORS:" $julesvalcheck | grep -oP '\d+(?= open)' | head -n 1)
	std=$(grep "FILE DESCRIPTORS:" $julesvalcheck | grep -oP '(?<=\()(\d+)(?= std)' | head -n 1)
	open=$((open - 1))
	if [ "$pipex_exit" -ne "$bash_exit" ]; then
		echo -n "❌"
		echo -e "$test_desc: Exit code incorrect" >> pipex_trace
		echo -e "Pipex exit code: $pipex_exit\nBash exit code: $bash_exit\n" >> pipex_trace
	elif grep -q "ERROR SUMMARY: [^0]" $julesvalcheck; then
		echo -n "❌"
		echo -e "$test_desc: Memory leak detected\n" >> pipex_trace
	elif ! [ $open -eq $std ]; then
		echo -n "❌"
		echo -e "$test_desc: Non standard file descriptor open" >> pipex_trace
		echo -e "Open: $open | Standard: $std\n" >> pipex_trace
	else
		echo -n "✅"
	fi
}

run_sleep()
{
	> .julesmemlog
	> $julesvalcheck
	local test_desc=$1
	local infile=$2
	local cmd1=$3
	local cmd2=$4
	local outfile=$5
	shift
	set -- $cmd1
	local split1=$1
	local arg1=$2
	set -- $cmd2
	local split2=$1
	local arg2=$2
	local start=$(date +%s)
	timeout 15 ${VALGRIND} ./pipex "$infile" "$cmd1" "$cmd2" "$outfile" 2> /dev/null 1> /dev/null
	pipex_exit=$?
	local end=$(date +%s)
	local runtime=$((end - start))
	if [ $pipex_exit -eq 124 ]; then
		echo -n "❌"
		echo -e "$test_desc: Pipex timed out\n" >> pipex_trace
		return
	elif [ $runtime -lt 9 ]; then
		echo -n "❌"
		echo -e "$test_desc: Pipex did not sleep long enough\n" >> pipex_trace
		return
	elif [ $runtime -gt 11 ]; then
		echo -n "❌"
		echo -e "$test_desc: Pipex slept too long\n" >> pipex_trace
		return
	fi
	grep --text "FILE DESCRIPTORS:" .julesmemlog  | sed 's/==[0-9]\+== //g' > $julesvalcheck
	grep --text "ERROR SUMMARY:" .julesmemlog  | sed 's/==[0-9]\+== //g' >> $julesvalcheck
	open=$(grep "FILE DESCRIPTORS:" $julesvalcheck | grep -oP '\d+(?= open)' | head -n 1)
	std=$(grep "FILE DESCRIPTORS:" $julesvalcheck | grep -oP '(?<=\()(\d+)(?= std)' | head -n 1)
	open=$((open - 1))
	if [ -s "$outfile" ]; then
		echo -n "❌"
		echo -e "$test_desc: Outfile not empty\n" >> pipex_trace
	elif grep -q "ERROR SUMMARY: [^0]" $julesvalcheck; then
		echo -n "❌"
		echo -e "$test_desc: Memory leak detected\n" >> pipex_trace
	elif ! [ $open -eq $std ]; then
		echo -n "❌"
		echo -e "$test_desc: Non standard file descriptor open" >> pipex_trace
		echo -e "Open: $open | Standard: $std\n" >> pipex_trace
	else
		echo -n "✅"
	fi
}

run_bonus()
{
	exec 2>/dev/null
	> $julesbashout
	> .julesmemlog
	> $julesdiff
	> $julesvalcheck
	> "$outfile"
	local test_desc=$1
	local infile=$2
	local cmd1=$3
	local cmd2=$4
	local cmd3=$5
	local outfile=$6
	shift
	set -- $cmd1
	local split1=$1
	local arg1=$2
	set -- $cmd2
	local split2=$1
	local arg2=$2
	set -- $cmd3
	local split3=$1
	local arg3=$2
	timeout 15 ${VALGRIND} ./pipex_bonus "$infile" "$cmd1" "$cmd2" "$cmd3" "$outfile"
	pipex_exit=$?
	if [ $pipex_exit -eq 124 ]; then
		echo -n "❌"
		echo -e "$test_desc: Pipex timed out\n" >> pipex_trace
		return
	fi
	< "$infile" $split1 $arg1  | $split2 $arg2  | $split3 $arg3 > $julesbashout
	bash_exit=$?
	grep --text "FILE DESCRIPTORS:" .julesmemlog  | sed 's/==[0-9]\+== //g' > $julesvalcheck
	grep --text "ERROR SUMMARY:" .julesmemlog  | sed 's/==[0-9]\+== //g' >> $julesvalcheck
	open=$(grep "FILE DESCRIPTORS:" $julesvalcheck | grep -oP '\d+(?= open)' | head -n 1)
	std=$(grep "FILE DESCRIPTORS:" $julesvalcheck | grep -oP '(?<=\()(\d+)(?= std)' | head -n 1)
	open=$((open - 1))
	if ! diff $julesbashout "$outfile" > $julesdiff; then
		echo -n "❌"
		echo -e "$test_desc: Output incorrect\n" >> pipex_trace
		cat $julesdiff >> pipex_trace
	elif [ "$pipex_exit" -ne "$bash_exit" ]; then
		echo -n "❌"
		echo -e "$test_desc: Exit code incorrect" >> pipex_trace
		echo -e "Pipex exit code: $pipex_exit\nBash exit code: $bash_exit\n" >> pipex_trace
	elif grep -q "ERROR SUMMARY: [^0]" $julesvalcheck; then
		echo -n "❌"
		echo -e "$test_desc: Memory leak detected\n" >> pipex_trace
	elif ! [ $open -eq $std ]; then
		echo -n "❌"
		echo -e "$test_desc: Non standard file descriptor open" >> pipex_trace
		echo -e "Open: $open | Standard: $std\n" >> pipex_trace
	else
		echo -n "✅"
	fi
}

run_heredoc()
{
	exec 2>/dev/null
	> $julesbashout
	> .julesmemlog
	> $julesdiff
	> $julesvalcheck
	> "$outfile"
	local test_desc=$1
	local infile=$2
	local cmd1=$4
	local cmd2=$5
	local outfile=$6
	shift
	set -- $cmd1
	local split1=$1
	local arg1=$2
	set -- $cmd2
	local split2=$1
	local arg2=$2
${VALGRIND} ./pipex_bonus "$infile" EOF "$cmd1" "$cmd2" "$outfile" << EOF
test
test
newline
nottest
EOF
	pipex_exit=$?
	cat $outfile > test
	if [ $pipex_exit -eq 124 ]; then
		echo -n "❌"
		echo -e "$test_desc: Pipex timed out\n" >> pipex_trace
		return
	fi
<< EOF $split1 $arg1  | $split2 $arg2  | $split3 $arg3 > $julesbashout
test
test
newline
nottest
EOF
	bash_exit=$?
	cat $julesbashout >> test
	grep --text "FILE DESCRIPTORS:" .julesmemlog  | sed 's/==[0-9]\+== //g' > $julesvalcheck
	grep --text "ERROR SUMMARY:" .julesmemlog  | sed 's/==[0-9]\+== //g' >> $julesvalcheck
	open=$(grep "FILE DESCRIPTORS:" $julesvalcheck | grep -oP '\d+(?= open)')
	std=$(grep "FILE DESCRIPTORS:" $julesvalcheck | grep -oP '(?<=\()(\d+)(?= std)')

	if ! diff $julesbashout "$outfile" > $julesdiff; then
		echo -n "❌"
		echo -e "$test_desc: Output incorrect\n" >> pipex_trace
		cat $julesdiff >> pipex_trace
	elif [ "$pipex_exit" -ne "$bash_exit" ]; then
		echo -n "❌"
		echo -e "$test_desc: Exit code incorrect" >> pipex_trace
		echo -e "Pipex exit code: $pipex_exit\nBash exit code: $bash_exit\n" >> pipex_trace
	elif grep -q "ERROR SUMMARY: [^0]" $julesvalcheck; then
		echo -n "❌"
		echo -e "$test_desc: Memory leak detected\n" >> pipex_trace
	elif ! [ $open -eq $std ]; then
		echo -n "❌"
		echo -e "$test_desc: Non standard file descriptor open" >> pipex_trace
		echo -e "Open: $open | Standard: $std\n" >> pipex_trace
	else
		echo -n "✅"
	fi
}

echo -e "
${PURPLE}##############################################${RESET}
${PURPLE}#${RESET}.${WHITE}########${RESET}..${WHITE}####${RESET}.${WHITE}########${RESET}..${WHITE}########${RESET}.${WHITE}##${RESET}.....${WHITE}##${PURPLE}#${RESET}
${PURPLE}#${RESET}.${WHITE}##${RESET}.....${WHITE}##${RESET}..${WHITE}##${RESET}..${WHITE}##${RESET}.....${WHITE}##${RESET}.${WHITE}##${RESET}........${WHITE}##${RESET}...${WHITE}##${RESET}.${PURPLE}#${RESET}
${PURPLE}#${RESET}.${WHITE}##${RESET}.....${WHITE}##${RESET}..${WHITE}##${RESET}..${WHITE}##${RESET}.....${WHITE}##${RESET}.${WHITE}##${RESET}.........${WHITE}##${RESET}.${WHITE}##${RESET}..${PURPLE}#${RESET}
${PURPLE}#${RESET}.${WHITE}########${RESET}...${WHITE}##${RESET}..${WHITE}########${RESET}..${WHITE}######${RESET}......${WHITE}###${RESET}...${PURPLE}#${RESET}
${PURPLE}#${RESET}.${WHITE}##${RESET}.........${WHITE}##${RESET}..${WHITE}##${RESET}........${WHITE}##${RESET}.........${WHITE}##${RESET}.${WHITE}##${RESET}..${PURPLE}#${RESET}
${PURPLE}#${RESET}.${WHITE}##${RESET}.........${WHITE}##${RESET}..${WHITE}##${RESET}........${WHITE}##${RESET}........${WHITE}##${RESET}...${WHITE}##${RESET}.${PURPLE}#${RESET}
${PURPLE}#${RESET}.${WHITE}##${RESET}........${WHITE}####${RESET}.${WHITE}##${RESET}........${WHITE}########${RESET}.${WHITE}##${RESET}.....${WHITE}##${PURPLE}#${RESET}
${PURPLE}##############################################${RESET}
"

trap "rm -rf $julestestinfile $julestestdir $julesbashout .julesmemlog $juleserror $julesvalcheck $julesdiff $julesout $julestestoutfile $julestestoutfile2 .julestestexe.c ../.julestestexe $current_dir/$julestestdir.julestestexe .script.sh" EXIT

if [ ! -f "./pipex" ]; then
	echo -e "${RED}Executable not found. Aborting test...\n${RESET}"
	exit 1
fi
if [ -f "pipex_trace" ]; then
	echo -e "\n============================================================\n" >> pipex_trace
fi
echo -e "----- TRACE BEGINS -----\n" >> pipex_trace

julestestinfile=$(mktemp)
julestestdir=$(mktemp -d)
julesbashout=$(mktemp)
juleserror=$(mktemp)
julesvalcheck=$(mktemp)
julesdiff=$(mktemp)
julesout=$(mktemp)
julestestinfile=$(mktemp)
julestestoutfile=$(mktemp)

echo -e "test\ntest\ntest\ntest\ngood\ngood\ngood\n\ntest\n" > $julestestinfile
echo -e "${PURPLE}--- ${WHITE}Basic Error Tests${PURPLE} ---\n${RESET}"
echo -e "-- Basic Error Tests --\n" >> pipex_trace

run_error "No arguments"
run_error "Too few arguments" $julestestinfile "wc -l" $julestestoutfile
run_error "Too many arguments" $julestestinfile "grep e" "wc -l" "wc -w" $julestestoutfile
echo -e "\n"

rm -rf $juleserror $julesvalcheck .julesmemlog $julestestoutfile $julesout

echo -e "${PURPLE}--- ${WHITE}Basic Tests${PURPLE} ---\n${RESET}"
echo -e "-- Basic Tests --\n" >> pipex_trace

run_pipex "Valid Input" $julestestinfile "grep e" "wc -l" $julestestoutfile
run_pipex "Infile doesn't exist" julestestinfile2 "grep e" "wc -l" $julestestoutfile
run_pipex "Outfile doesn't exist" $julestestinfile "grep e" "wc -l" .julestestoutfile2
run_pipex "Command 1 doesn't exist" $julestestinfile "a" "wc -l" $julestestoutfile
run_pipex "Command 2 doesn't exist" $julestestinfile "grep e" "a" $julestestoutfile
run_pipex "Neither command exists" $julestestinfile "a" "a" $julestestoutfile

chmod 111 $julestestinfile
run_permissions "Infile permissions removed" $julestestinfile "grep e" "wc -l" $julestestoutfile
> $julestestoutfile
> $julesbashout
chmod 111 $julesbashout
chmod 111 $julestestoutfile
run_permissions "Outfile permissions removed" $julestestinfile "grep e" "wc -l" $julestestoutfile
run_pipex "Quoted argument" $julestestinfile "grep 'quote this'" "wc -l" $julestestoutfile
run_pipex "Command 1 empty" $julestestinfile '""' "wc -l" $julestestoutfile
run_pipex "Command 2 empty" $julestestinfile "grep e" '""' $julestestoutfile
run_pipex "Both commands empty" $julestestinfile '""' '""' $julestestoutfile
temp=$julesbashout
julesbashout=""
run_special_case "All input empty" "" "" "" ""
julesbashout=$temp
temp=$PATH
unset $PATH
run_pipex_no_path "No PATH variable" $julestestinfile "grep test" "wc -l" $julestestoutfile
export "PATH=$temp"
echo -e "\n"

rm -rf $julesbashout .julesmemlog $julesdiff $julesvalcheck .julestestoutfile2 

echo -e "${PURPLE}--- ${WHITE}File Type Tests${PURPLE} ---\n${RESET}"
echo -e "-- File Type Tests --\n" >> pipex_trace

run_pipex "Command 1 is a directory" $julestestinfile "$julestestdir" "wc -l" $julestestoutfile
run_pipex "Command 2 is a directory" $julestestinfile "grep e" "$julestestdir" $julestestoutfile
run_pipex "Both commands are directories" $julestestinfile "$julestestdir" "$julestestdir" $julestestoutfile
run_pipex "Infile is a directory" $julestestdir "grep e" "wc -l" $julestestoutfile
temp=$julesbashout
julesbashout=$(mktemp -d)
run_special_case "Outfile is a directory" $julestestinfile "grep e" "wc -l" $julestestdir
run_special_case "Both files are directories" $julestestdir "grep e" "wc -l" $julestestdir
run_special_case "All input are directories" $julestestdir $julestestdir $julestestdir $julestestdir
rm -rf $julesbashout
julesbashout=$temp
echo '#include <stdio.h>

int main()
{
	printf("This\nis\na\ntest\nprogram\n");
	return (0);
}' > .julestestexe.c
cc julestestexe.c -o ../.julestestexe
run_pipex "Command 1 is a relative path" $julestestinfile "../.julestestexe" "wc -l" $julestestoutfile # relative path test
rm -rf .././.julestestexe
current_dir=$(pwd)
cc julestestexe.c -o "$current_dir/$julestestdir.julestestexe"
run_pipex "Command 1 is an absolute path" $julestestinfile "$current_dir/$julestestdir.julestestexe" "wc -l" $julestestoutfile # absolute path
rm -rf "$current_dir/.julestestdir
echo "#!/bin/bash
echo HELLO > .script.sh
run_pipex "Command 1 is a script" $julestestinfile "sh .script.sh" "wc -l" $julestestoutfile # script as cmd
rm -rf .script.sh
echo -e "\n"

echo -e "${PURPLE}--- ${WHITE}Sleep Tests${PURPLE} ---\n${RESET}"
echo -e "-- Sleep Tests --\n" >> pipex_trace

run_sleep "Both commands are sleep 10" $julestestinfile "sleep 10" "sleep 10" $julestestoutfile # sleep test same
run_sleep "Command 1 is sleep 10, command 2 is sleep 5" $julestestinfile "sleep 10" "sleep 5" $julestestoutfile # sleep diff
run_sleep "Command 1 is sleep 5, command 2 is sleep 10" $julestestinfile "sleep 5" "sleep 10" $julestestoutfile
echo -e "\n"

rm -rf $julestestinfile $julestestoutfile .julesmemlog $julesvalcheck .julestestexe.c

if [ -f "./pipex_bonus" ]; then
	echo -e "${PURPLE}--- ${WHITE}Bonus Tests${PURPLE} ---\n${RESET}"
	echo -e "-- Bonus Tests --\n" >> pipex_trace

	run_bonus "3 Commands" $julestestinfile "grep e" "wc -l" "wc -w" $julestestoutfile
	run_heredoc "heredoc" "heredoc" "grep test" "wc -l" $julestestoutfile
	echo -e "\n"

else
	echo -e "${PURPLE}--- ${WHITE}Bonus not found. Ending testing...${PURPLE} ---\n${RESET}"
fi
echo -e "---- TRACE ENDS ----" >> pipex_trace
echo -e "${PURPLE}--- ${WHITE}Testing complete: pipex_trace created${PURPLE} ---\n${RESET}"

# Created by Jules Pierce @ Hive Helsinki 2025/02/20 - https://github.com/Jules478
