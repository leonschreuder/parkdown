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
  input="$(cat -)"

  while IFS=$'\n' read  -r line; do

    # simply print empty lines from input directly
    [[ "$line" == "" ]] &&
      echo "" && continue

    [[ "$IN_BLOCK" != true ]] &&
      startNewBlock "$line"

    buildLinesFromWords "$line"

  done <<< "$input"
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
  pushStack "$LINE_BUILDER" # might contain last line.
  LINE_BUILDER=""
  balanceLinesInStack
  checkEdgeCase
  emptyStack
  IN_BLOCK=false
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

    [[ "$LINE_BUILDER" == "" ]] &&
      LINE_BUILDER="$word" &&
      continue

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

pushStack() {
  if [[ "$STACK3" != "" ]]; then
    lineToPrint="$STACK3"
    if [[ "$listItem" != "" && "$lineToPrint" != "$listItem"* ]]; then
      # we're currently printing a list, but this line doesn't have the prefix
      lineToPrint="  $lineToPrint"
    fi
    if [[ "$prefix" != "" ]]; then
      lineToPrint="$prefix $lineToPrint"
    fi
    lineToPrint="$indent$lineToPrint"
    echo "$lineToPrint"
  fi
  STACK3="$STACK2"
  STACK2="$STACK1"
  STACK1="$1"
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
  while [[ "$STACK1$STACK2$STACK3" != "" ]]; do
    pushStack ""
  done
}

if [[ "$0" == "$BASH_SOURCE" ]]; then
  main $@
fi
