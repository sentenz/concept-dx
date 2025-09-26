#!/bin/bash
#
# Fromat for wrapper actions.

set -o pipefail

# Converts ShellCheck JSON report to GitLab Code Quality report.
#
# Reads either from standard input or a specified file, converts linter findings
# to code quality format, and writes results to gl-code-quality-report.json.
#
# Globals:
#   None
# Arguments:
#   $1 (optional) - Path to input ShellCheck JSON file. Defaults to stdin.
#   $2 (optional) - Path to output GitLab Code Quality report JSON file. Defaults to gl-code-quality-report.json.
# Outputs:
#   Writes GitLab Code Quality report to specified output file.
# Returns:
#   0 on success, non-zero on jq processing error or invalid input.
#
# Requirements:
#   - jq
#   - md5sum
#
# Usage:
#   # Read from file
#   format_gitlab_shellcheck shellcheck-report.json
#
#   # Read from stdin
#   cat shellcheck-report.json | format_gitlab_shellcheck
format_gitlab_shellcheck() {
  local input_file="${1:-/dev/stdin}"
  local output_file="${2:-gl-code-quality-report.json}"

  # XXX Replace `@base64` encoding with a `md5sum` hashing algorithm for computing fingerprint
  jq '
    map({
      description: ("Linter ShellCheck - " + .message),
      check_name: "SC\(.code)",
      fingerprint: ((.file + ":" + (.line | tostring) + ":" + (.code | tostring)) | @base64),
      severity: (
        if .level | ascii_downcase | test("error") then "critical"
        elif .level | ascii_downcase | test("warning") then "major"
        elif .level | ascii_downcase | test("info") then "minor"
        elif .level | ascii_downcase | test("style") then "info"
        else "unknown"
        end
      ),
      location: {
        path: .file,
        lines: {
          begin: .line
        }
      }
    })
  ' "${input_file}" > "${output_file}"
}

# Converts shfmt diff output to GitLab Code Quality report format.
#
# Parses shfmt's diff output to create code quality findings for formatting issues.
# Handles both file input and stdin, producing a standardized JSON report.
#
# Globals:
#   None
# Arguments:
#   $1 (optional) - Path to input shfmt diff file. Defaults to stdin.
#   $2 (optional) - Output file path. Defaults to gl-code-quality-report.json.
# Outputs:
#   Writes GitLab Code Quality report to specified output file.
# Returns:
#   0 on success, non-zero on parsing errors or missing dependencies
#
# Usage:
#   # Read from file
#   format_gitlab_shfmt shfmt.diff
#
#   # Read from stdin
#   shfmt -d myscript.sh | format_gitlab_shfmt
#
# Requirements:
#   - jq
#   - md5sum
format_gitlab_shfmt() { 
  local output_file="${1:-gl-code-quality-report.json}"

  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is not installed." >&2
    return 1
  fi

  if ! command -v md5sum >/dev/null 2>&1; then
    echo "Error: md5sum is not installed." >&2
    return 1
  fi

  local gitlab_results=()
  # Read the shfmt diff output from stdin
  while IFS= read -r finding; do
    # Identify file paths and change lines
    if [[ "${finding}" =~ ^---[[:space:]]([[:alnum:][:punct:]]+)\.orig$ ]]; then
      # Capture the original file path
      original_file="${BASH_REMATCH[1]}"
    elif [[ "${finding}" =~ ^\+\+\+[[:space:]]([[:alnum:][:punct:]]+)$ ]]; then
      # Capture the modified file path
      modified_file="${BASH_REMATCH[1]}"
    elif [[ "${finding}" =~ ^@@[[:space:]]-([0-9]+),[0-9]+[[:space:]]\+([0-9]+), ]]; then
      # Capture the line number where the change starts
      original_line="${BASH_REMATCH[1]}"
      line_number="${BASH_REMATCH[2]}"
    elif [[ "${finding}" =~ ^([+-]) ]]; then
      # Identify the nature of the change
      change_type="${BASH_REMATCH[1]}"
      
      # Use the modified line number for the change location
      if [[ "${change_type}" == "+" ]]; then
        local check_name="Shfmt"
        local severity="info"
        local description="Shell formatting change required."

        # Generate a unique fingerprint based on file, line, and type
        local fingerprint
        fingerprint=$(echo -n "${modified_file}:${line_number}:${change_type}" | md5sum | awk '{print $1}')

        # Create a GitLab Code Quality entry
        local entry
        entry=$(jq -n \
          --arg description "Formatter ${check_name} - ${description}" \
          --arg check_name "${check_name}" \
          --arg fingerprint "${fingerprint}" \
          --arg severity "${severity}" \
          --arg path "${modified_file}" \
          --argjson lines "{ \"begin\": ${line_number} }" \
          '{
            description: $description,
            check_name: $check_name,
            fingerprint: $fingerprint,
            severity: $severity,
            location: {
              path: $path,
              lines: $lines
            }
          }'
        )

        # Add the entry to the GitLab results array
        gitlab_results+=("${entry}")

        # Increment modified line number for next change
        line_number=$((line_number + 1))
      fi
    fi
  done

  # Output the results to a file, merging with existing entries if the file exists
  printf "%s\n" "${gitlab_results[@]}" | jq -s '.' > "${output_file}"

  echo "GitLab Code Quality report generated: ${output_file}"
}

# Converts shfmt diff output to GitLab Code Quality report format.
#
# Parses shfmt's diff output to create code quality findings for formatting issues.
# Handles both file input and stdin, producing a standardized JSON report.
#
# Globals:
#   None
# Arguments:
#   $1 (optional) - Path to input shfmt diff file. Defaults to stdin.
#   $2 (optional) - Output file path. Defaults to gl-code-quality-report.json.
# Outputs:
#   Writes GitLab Code Quality report to specified output file
# Returns:
#   0 on success, non-zero on parsing errors or missing dependencies
#
# Usage:
#   # Read from file
#   format_gitlab_shfmt shfmt.diff
#
#   # Read from stdin
#   shfmt -d myscript.sh | format_gitlab_shfmt
format_gitlab_shfmt2() {
  local input_file="${1:-/dev/stdin}"
  local output_file="${2:-gl-code-quality-report.json}"
  local current_file=""
  local line_range=""
  local -a gitlab_entries=()

  # Parse shfmt diff output
  while IFS= read -r line; do
    # Track current file
    if [[ "${line}" =~ ^\+\+\+ ]]; then
      current_file="${line#+++ }"
      current_file="${current_file%.orig}"  # Remove .orig suffix if present
    fi

    # Parse line ranges
    if [[ "${line}" =~ ^@@\ -[0-9]+(,[0-9]+)?\ \+([0-9]+)(,[0-9]+)?\ @@ ]]; then
      line_range="${BASH_REMATCH[2]}"
    fi

    # Process diff lines
    if [[ "${line}" =~ ^([+-]) ]]; then
      local change_type="${BASH_REMATCH[1]}"
      local line_number=$((line_range++))

      # Only report additions (formatting changes needed)
      if [[ "${change_type}" == "+" ]]; then
        local fingerprint
        fingerprint=$(echo -n "${current_file}:${line_number}:${line}" | md5sum | awk '{print $1}')

        gitlab_entries+=("$(jq -n \
          --arg description "Formatter Shfmt - Shell formatting change required." \
          --arg check "shfmt" \
          --arg fingerprint "${fingerprint}" \
          --arg severity "info" \
          --arg path "${current_file}" \
          --argjson line "${line_number}" \
          '{
            description: $description,
            check_name: $check,
            fingerprint: $fingerprint,
            severity: $severity,
            location: {
              path: $path,
              lines: { begin: $line }
            }
          }')")
      fi
    fi
  done < "${input_file}"

  # Generate final report
  if (( ${#gitlab_entries[@]} > 0 )); then
    printf "%s\n" "${gitlab_entries[@]}" | jq -s '.' > "${output_file}"
  else
    echo "[]" > "${output_file}"
  fi
}

# Converts GitLab SAST report (Semgrep format) to GitLab Code Quality report.
#
# Reads either from standard input or a specified file, converts vulnerability
# findings to code quality format, and writes results to gl-code-quality-report.json.
#
# Globals:
#   None
# Arguments:
#   $1 (optional) - Path to input GitLab SAST report JSON file. Defaults to stdin.
#   $2 (optional) - Path to output GitLab Code Quality report JSON file. Defaults to gl-code-quality-report.json.
# Outputs:
#   Writes GitLab Code Quality report JSON file.
# Returns:
#   0 on success, non-zero on jq processing error or invalid input.
#
# Requirements:
#   - jq
#   - md5sum
#
# Usage:
#   format_gitlab_semgrep [input_file] [output_file]
#
#   # Read from stdin
#   cat gl-sast-report.json | format_gitlab_semgrep
format_gitlab_semgrep() {
  local input_file="${1:-/dev/stdin}"
  local output_file="${2:-gl-code-quality-report.json}"

  # XXX Replace `@base64` encoding with a `md5sum` hashing algorithm for computing fingerprint
  jq '
    .vulnerabilities | map({
      description: ("SAST " + .scanner.name + " - " + .message + " - See " + .identifiers[0].url),
      check_name: .identifiers[0].value,
      fingerprint: .id,
      severity: (
        if .severity | ascii_downcase | test("critical") then "critical"
        elif .severity | ascii_downcase | test("high") then "major"
        elif .severity | ascii_downcase | test("medium") then "minor"
        elif .severity | ascii_downcase | test("low") then "minor"
        elif .severity | ascii_downcase | test("info") then "info"
        elif .severity | ascii_downcase | test("unknown") then "info"
        else "info"
        end
      ),
      location: {
        path: .location.file,
        lines: {
          begin: .location.start_line
        }
      },
      identifiers: [
        {
          url: .identifiers[0].url
        }
      ]
    })
  ' "${input_file}" > "${output_file}"
}

# Converts Gitleaks JSON to GitLab Code Quality report.
#
# Reads either from standard input or a specified file, converts secrets
# detectings to code quality format, and writes results to gl-code-quality-report.json.
#
# Globals:
#   None
# Arguments:
#   $1 (optional) - Path to input Gitleaks JSON file. Defaults to stdin.
#   $2 (optional) - Path to output GitLab Code Quality report JSON file. Defaults to gl-code-quality-report.json.
# Outputs:
#   Writes GitLab Code Quality report JSON file.
# Returns:
#   0 on success, non-zero on jq processing error or invalid input.
#
# Requirements:
#   - jq
#   - md5sum
#
# Usage:
#   format_gitlab_gitleaks [input_file] [output_file]
#
#   # Read from stdin
#   cat gl-sast-report.json | format_gitlab_gitleaks
format_gitlab_gitleaks() {
  local input_file="${1:-/dev/stdin}"
  local output_file="${2:-gl-code-quality-report.json}"

  # XXX Replace `@base64` encoding with a `md5sum` hashing algorithm for computing fingerprint
  jq '
    map({
      description: ("Secrets Gitleaks - " + .Description),
      check_name: .RuleID,
      fingerprint: ((.Fingerprint + ":" + (.Entropy | tostring) + ":" + .File) | @base64),
      severity: "major",
      location: {
        path: .File,
        lines: {
          begin: .StartLine
        }
      },
      remediate: .Fingerprint
    })
  ' "${input_file}" > "${output_file}"
}

# Converts ansible-lint JSON output to GitLab Code Quality report.
#
# Reads either from standard input or a specified file, transforms the ansible-lint
# output into a GitLab Code Quality JSON report, and writes the results to a file.
#
# Globals:
#   None
# Arguments:
#   $1 (optional) - Path to input ansible-lint JSON file. Defaults to stdin.
#   $2 (optional) - Path to output GitLab Code Quality report JSON file. Defaults to gl-code-quality-report.json.
# Outputs:
#   Writes GitLab Code Quality report JSON file.
# Returns:
#   0 on success, non-zero on jq processing error or invalid input.
#
# Requirements:
#   - jq
#
# Usage:
#   format_gitlab_ansible_lint [input_file] [output_file]
#
#   # Read from stdin
#   cat ansible-lint-report.json | format_gitlab_ansible_lint
function format_gitlab_ansible_lint() {
  local input_file="${1:-/dev/stdin}"
  local output_file="${2:-gl-code-quality-report.json}"

  jq '
    map({
      description: ("Linter Ansible-Lint - " + .check_name + ": " + .description + " - See " + .url),
      check_name: .check_name,
      fingerprint: .fingerprint,
      severity: .severity,
      location: .location
    })
  ' "${input_file}" > "${output_file}"
}