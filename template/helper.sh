#!/bin/bash
# Shared helper functions for update.sh and process-template.sh

# --- Minifier ---
min() {
  sed 's|/\*[^*]*\*\+\([^/][^*]*\*\+\)*/||g; s/^ *//; s/ *$//; /^$/d; s/  */ /g' "$1"
}

# --- JSON Helpers ---
json_val() {
  sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -1
}

json_flag() {
  grep -q "\"$2\"[[:space:]]*:[[:space:]]*true" "$1"
}

json_num() {
  sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p' "$1" | head -1
}

json_img() {
  sed -n 's/.*"images"[[:space:]]*:[[:space:]]*\["\([^"]*\)".*/\1/p' "$1" | head -1
}

json_nested() {
  sed -n '/"'"$2"'"/,/^[[:space:]]*}/p' "$1" \
    | sed -n 's/.*"'"$3"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

json_label() {
  sed -n '/"labels"/,/}/p' "$SITE_JSON" \
    | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

# Read array items from a nested JSON section
# Usage: json_nested_array "file" "section" "key" → one value per line
json_nested_array() {
  sed -n '/"'"$2"'"/,/^[[:space:]]*}/p' "$1" \
    | tr '\n' ' ' \
    | sed -n 's/.*"'"$3"'"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' \
    | tr ',' '\n' \
    | sed -n 's/.*"\([^"]*\)".*/\1/p'
}

# --- Address Reader ---
# Reads "address" JSON array from a file, joins lines with a separator
# Usage: read_address "file.json" "<br>" → lines joined with <br>
#        read_address "file.json" ", "  → lines joined with comma
read_address() {
  local file="$1" sep="$2" in_addr=0 result="" first=1
  while IFS= read -r line; do
    [[ "$line" == *'"address"'* ]] && { in_addr=1; continue; }
    [ $in_addr -eq 0 ] && continue
    [[ "$line" == *']'* ]] && break
    local v=$(echo "$line" | sed -n 's/^[[:space:]]*"\(.*\)"[[:space:],]*$/\1/p')
    if [ -n "$v" ]; then
      [ $first -eq 0 ] && result+="$sep"
      result+="$v"; first=0
    fi
  done < "$file"
  printf '%s' "$result"
}

# --- Utility ---
blur_src() {
  local src="$1"
  printf '%s' "${src%.webp}-k.webp"
}

# --- Routing ---
is_root_page() {
  echo ",$ROOT_PAGES," | grep -q ",$1,"
}

page_href() {
  local name="$1"
  if is_root_page "$name"; then
    printf '/%s.html' "$name"
  else
    printf '/%s/%s.html' "$PAGES_DIR" "$name"
  fi
}

page_output_path() {
  local name="$1"
  if is_root_page "$name"; then
    printf '%s/%s.html' "$OUTPUT_DIR" "$name"
  else
    printf '%s/%s/%s.html' "$OUTPUT_DIR" "$PAGES_DIR" "$name"
  fi
}

# --- Template Engine ---
render_template() {
  local content="$1"
  shift
  while [ $# -ge 2 ]; do
    local key="$1" val="$2"
    # Bash 5.2+: & and \ are special in replacement strings
    val="${val//\\/\\\\}"
    val="${val//&/\\&}"
    content="${content//\{\{$key\}\}/$val}"
    shift 2
  done
  printf '%s' "$content"
}

apply_layout() {
  local tpl_file="$1"
  shift
  local content tpl_dir
  content=$(<"$tpl_file")
  tpl_dir=$(dirname "$tpl_file")

  local partial_name partial_content partial_file
  while [[ "$content" == *'{{partial:'* ]]; do
    partial_name=$(printf '%s' "$content" \
      | grep -o '{{partial:[^}]*}}' | head -1 \
      | sed 's/{{partial:\([^}]*\)}}/\1/')
    [ -z "$partial_name" ] && break
    partial_file="$tpl_dir/partials/${partial_name}.html"
    partial_content=""
    [ -f "$partial_file" ] && partial_content=$(<"$partial_file")
    partial_content="${partial_content//\\/\\\\}"
    partial_content="${partial_content//&/\\&}"
    content="${content//\{\{partial:${partial_name}\}\}/$partial_content}"
  done

  render_template "$content" "$@"
}
