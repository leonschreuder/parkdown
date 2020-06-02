#!/bin/bash

export MAX_LINE_LENGTH=72

main() {
  LINE_BUILDER=""
  while read -r line; do
    splitLineForLength "$line"
  done <<< "$(cat -)"

  pushStack "$LINE_BUILDER"
  balanceLinesInStack
  checkEdgeCase
  emptyStack
}

splitLineForLength() {
  for word in $line; do
    [[ "$LINE_BUILDER" == "" ]] && LINE_BUILDER="$word" && continue

    newConcat="$LINE_BUILDER $word"
    if [[ ${#newConcat} -lt $MAX_LINE_LENGTH ]];then
      LINE_BUILDER="$newConcat"
    else
      pushStack "$LINE_BUILDER"
      balanceLinesInStack
      LINE_BUILDER="$word"
    fi
  done
}

pushStack() {
  [[ "$STACK3" != "" ]] && echo "$STACK3"
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
