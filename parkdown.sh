#!/bin/bash

export MAX_LINE_LENGTH=72

printHelp() {
  echo "Parkdown v0.1

Formatting like 'par' but more aimed at markdown-style text editing.

Usage:
./parkdown.sh [-h] <<< "input"

-h                Print this help
-w<number>        Specify width to use. Currently defaults to '$MAX_LINE_LENGTH'
"
}

main() {
  while getopts 'hw:' opt; do
    case $opt in
      h)
        printHelp
        exit
        ;;
      w)
        MAX_LINE_LENGTH=$OPTARG
        ;;
    esac
  done
  shift "$((OPTIND - 1))"

  LINE_LENGTH=$MAX_LINE_LENGTH
  # input="$(</dev/stdin)"
  # echo "i:'$input'" >&2

  while IFS=$'\n' read -d $'\n' -r line; do
    [[ -n ${DEBUG+x} ]] && echo "l:'$line'" >&2

    # simply print empty lines from input directly
    if [[ "$line" == "" ]]; then

      if [[ "$IN_BLOCK" == true ]]; then
        closeBlock
      fi

      pushStack ""

    else

      if [[ "$IN_BLOCK" != true ]]; then
        startNewBlock "$line"
      fi

      buildLinesFromWords "$line"
    fi

  done # <<< "$input"
  closeBlock
}

startNewBlock() {
  line="$1"
  closeBlock

  IN_BLOCK=true
  LINE_BUILDER=""
  if [[ "$line" =~ ^([[:space:]]*)(#|//)?  ]]; then
    indentChecked=true
    indent="${BASH_REMATCH[1]}"
    prefix="${BASH_REMATCH[2]}"
    LINE_LENGTH=$((MAX_LINE_LENGTH - ( ${#indent} + ${#prefix} ) ))
  fi
}

closeBlock() {
  if [[ "$LINE_BUILDER" != "" ]]; then
    pushStack "$LINE_BUILDER" # might contain last line.
  fi
  unset LINE_BUILDER
  balanceLinesInStack
  checkEdgeCase
  emptyStack
  IN_BLOCK=false
  unset indent prefix
}

buildLinesFromWords() {
  line="$1"
  if [[ "$line" =~ ^[[:space:]]*-  ]]; then
    listItem="-"
    startNewBlock "$line"
  fi

  for word in $line; do
    [[ "$prefix" != "" && "$word" == "$prefix" ]] &&
      continue

    if [[ "$LINE_BUILDER" == "" ]]; then
      LINE_BUILDER="$word"
      continue
    fi

    lineWithAddedWord="$LINE_BUILDER $word"
    if [[ ${#lineWithAddedWord} -lt $LINE_LENGTH ]];then
      LINE_BUILDER="$lineWithAddedWord"
    else
      pushStack "$LINE_BUILDER"
      balanceLinesInStack
      LINE_BUILDER="$word"
    fi
  done
}

printStackItem() {
  bufName="$1"
  bufValue="${!bufName}"
  lineToPrint="$bufValue"
  if [[ "$listItem" != "" && "$lineToPrint" != "$listItem"* ]]; then
    # we're currently printing a list, but this line doesn't have the prefix
    lineToPrint="  $lineToPrint"
  fi
  if [[ "$prefix" != "" ]]; then
    lineToPrint="$prefix $lineToPrint"
  fi
  lineToPrint="$indent$lineToPrint"
  echo "$lineToPrint"
}

pushStack() {
  if [[ -n ${STACK3+x} ]]; then
    printStackItem "STACK3"
  fi
  if [[ -n ${STACK2+x} ]];then 
    STACK3="$STACK2"
  fi
  if [[ -n ${STACK1+x} ]];then
    STACK2="$STACK1"
  fi
  STACK1="$1"
  logStack
}

logStack() {
  if [[ -n ${DEBUG+x} ]]; then
    s1=null; s2=null; s3=null
    [[ -n ${STACK3+x} ]] && s3="'$STACK3'"
    [[ -n ${STACK2+x} ]] && s2="'$STACK2'"
    [[ -n ${STACK1+x} ]] && s1="'$STACK1'"
    echo -e "-- stack --\n\t3:$s3\n\t2:$s2\n\t1:$s1" >&2
  fi
}

balanceLinesInStack() {
  balanceBufferes "STACK2" "STACK1"
}

checkEdgeCase() {
  # In balancing a last line that is not to short, the
  # last line can become longer than the previous one, which
  # looks just weird. Compare the last stack item with the one
  # before it to balance out line[-1] and line[-2].
  balanceBufferes "STACK3" "STACK2"
}

# Shifts the last word from the first buffer into the second, and compares the
# length of the lines to see if they are closer in length. If so, than they are
# replaced with the more balanced version
balanceBufferes() {
  bufAName="$1"
  bufBName="$2"
  bufAValue="${!bufAName}"
  bufBValue="${!bufBName}"
  if [[ "$bufAValue" != "" && "$bufBValue" != "" ]]; then
    bufAShortened="${bufAValue%\ *}"
    bufBPrefixed="${bufAValue##*\ } $bufBValue"
    diffOriginal=$(( ${#bufAValue} - ${#bufBValue} ))
    diffShifted=$(( ${#bufAShortened} - ${#bufBPrefixed} ))
    if [[ "${diffShifted#-}" -lt "${diffOriginal#-}" ]]; then
      printf -v "$bufAName" '%s' "$bufAShortened"
      printf -v "$bufBName" '%s' "$bufBPrefixed"
    fi
  fi
}

emptyStack() {
  [[ -n ${STACK3+x} ]] && printStackItem "STACK3"
  [[ -n ${STACK2+x} ]] && printStackItem "STACK2"
  [[ -n ${STACK1+x} ]] && printStackItem "STACK1"
  unset STACK1 STACK2 STACK3
  # while [[ "$STACK1$STACK2$STACK3" != "" ]]; do
  #   pushStack ""
  # done
}

if [[ "$0" == "$BASH_SOURCE" ]]; then
  main $@
fi
