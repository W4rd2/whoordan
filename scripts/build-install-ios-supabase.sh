#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-"$ROOT_DIR/.env"}"
DEVICE_ID="${DEVICE_ID:-00008150-000E69EC36F8401C}"
DESTINATION="${DESTINATION:-platform=iOS,id=$DEVICE_ID}"
INSTALL_DEVICE_ID="${INSTALL_DEVICE_ID:-}"
DEVICE_WAIT_TIMEOUT="${DEVICE_WAIT_TIMEOUT:-30}"
SKIP_INSTALL="${SKIP_INSTALL:-0}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-0}"
PROJECT_PATH="${PROJECT_PATH:-"$ROOT_DIR/Whoordan.xcodeproj"}"
SCHEME="${SCHEME:-Whoordan}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-"$HOME/Library/Developer/Xcode/DerivedData/Whoordan-gntghfgfuinbhsbmjrbrhkseexyp"}"

mask_id() {
  local value="$1"
  if [[ "${#value}" -le 12 ]]; then
    printf '%s' "$value"
  else
    printf '%s...%s' "${value:0:8}" "${value: -4}"
  fi
}

if [[ ! -f "$ENV_FILE" ]]; then
  printf 'Missing env file: %s\n' "$ENV_FILE" >&2
  exit 1
fi

trim_shell_value() {
  local value="$1"
  value="${value%$'\r'}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

forbidden_env_key_pattern='(^|_)(SERVICE_ROLE|SECRET_KEY|PRIVATE_KEY)($|_)|(^|_)(OPENAI_API_KEY|CODEX_API_KEY)($|_)|SUPABASE_SERVICE_ROLE|SUPABASE_SECRET'

validate_env_file_keys() {
  local line trimmed key
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(trim_shell_value "$line")"
    [[ -z "$trimmed" || "${trimmed:0:1}" == "#" ]] && continue
    if [[ "$trimmed" == export[[:space:]]* ]]; then
      trimmed="$(trim_shell_value "${trimmed#export}")"
    fi
    [[ "$trimmed" == *=* ]] || continue
    key="$(trim_shell_value "${trimmed%%=*}")"
    if [[ "$key" =~ $forbidden_env_key_pattern ]]; then
      printf 'Refusing to use %s because %s is not allowed in the iPhone install environment.\n' "$ENV_FILE" "$key" >&2
      exit 1
    fi
  done < "$ENV_FILE"
}

read_env_value() {
  local requested_key="$1"
  local line trimmed key raw value
  value=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(trim_shell_value "$line")"
    [[ -z "$trimmed" || "${trimmed:0:1}" == "#" ]] && continue
    if [[ "$trimmed" == export[[:space:]]* ]]; then
      trimmed="$(trim_shell_value "${trimmed#export}")"
    fi
    [[ "$trimmed" == *=* ]] || continue
    key="$(trim_shell_value "${trimmed%%=*}")"
    [[ "$key" == "$requested_key" ]] || continue
    raw="$(trim_shell_value "${trimmed#*=}")"
    if [[ "$raw" == \"*\" && "$raw" == *\" && "${#raw}" -ge 2 ]]; then
      raw="${raw:1:${#raw}-2}"
    elif [[ "$raw" == \'*\' && "$raw" == *\' && "${#raw}" -ge 2 ]]; then
      raw="${raw:1:${#raw}-2}"
    else
      raw="$(trim_shell_value "${raw%%#*}")"
    fi
    value="$raw"
  done < "$ENV_FILE"
  printf '%s' "$value"
}

validate_publishable_key() {
  local value="$1"
  if [[ "$value" == sb_secret_* || "$value" == *service_role* || "$value" == *SERVICE_ROLE* ]]; then
    printf 'Refusing to use a Supabase secret/service-role key for a mobile install build.\n' >&2
    exit 1
  fi
  if [[ "$value" == *.*.* ]]; then
    if /usr/bin/python3 - "$value" <<'PY'
import base64
import json
import sys

token = sys.argv[1]
parts = token.split(".")
if len(parts) < 2:
    sys.exit(0)

payload_segment = parts[1] + "=" * (-len(parts[1]) % 4)
try:
    payload = json.loads(
        base64.urlsafe_b64decode(payload_segment.encode("utf-8")).decode("utf-8")
    )
except Exception:
    sys.exit(0)

sys.exit(1 if payload.get("role") == "service_role" else 0)
PY
    then
      :
    else
      printf 'Refusing to use a Supabase service-role JWT for a mobile install build.\n' >&2
      exit 1
    fi
  fi
}

validate_env_file_keys

PROJECT_ID="${SUPABASE_PROJECT_ID:-$(read_env_value SUPABASE_PROJECT_ID)}"
PUBLISHABLE_KEY="${WHOORDAN_SUPABASE_PUBLISHABLE_KEY:-$(read_env_value WHOORDAN_SUPABASE_PUBLISHABLE_KEY)}"
if [[ -z "$PUBLISHABLE_KEY" ]]; then
  PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-$(read_env_value SUPABASE_PUBLISHABLE_KEY)}"
fi
if [[ -z "$PUBLISHABLE_KEY" ]]; then
  PUBLISHABLE_KEY="${SUPABASE_ANON_KEY:-$(read_env_value SUPABASE_ANON_KEY)}"
fi
if [[ -z "$PROJECT_ID" ]]; then
  printf 'SUPABASE_PROJECT_ID is required in %s\n' "$ENV_FILE" >&2
  exit 1
fi

if [[ -z "$PUBLISHABLE_KEY" ]]; then
  printf 'SUPABASE_PUBLISHABLE_KEY or WHOORDAN_SUPABASE_PUBLISHABLE_KEY is required in %s\n' "$ENV_FILE" >&2
  exit 1
fi
validate_publishable_key "$PUBLISHABLE_KEY"

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT

resolve_install_device() {
  local devices_json="$temp_dir/devices.json"
  local devices_log="$temp_dir/devicectl-list.log"
  if ! xcrun devicectl list devices --timeout "$DEVICE_WAIT_TIMEOUT" --json-output "$devices_json" >"$devices_log" 2>&1; then
    printf 'Unable to query paired iOS devices with devicectl.\n' >&2
    sed -E 's/[A-Fa-f0-9-]{20,}/[device-id-redacted]/g' "$devices_log" >&2 || true
    return 1
  fi

  /usr/bin/python3 - "$devices_json" "$DEVICE_ID" <<'PY'
import json
import sys

path, requested = sys.argv[1:]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)

for device in data.get("result", {}).get("devices", []):
    identifier = device.get("identifier")
    hardware = device.get("hardwareProperties", {})
    properties = device.get("deviceProperties", {})
    connection = device.get("connectionProperties", {})
    candidates = {
        identifier,
        hardware.get("udid"),
        properties.get("name"),
    }
    if requested in candidates:
        print(identifier or requested)
        print(properties.get("name") or "iOS device")
        print(connection.get("transportType") or "unknown")
        print(connection.get("pairingState") or "unknown")
        sys.exit(0)

sys.exit(1)
PY
}

if [[ -z "$INSTALL_DEVICE_ID" ]]; then
  resolved_device_file="$temp_dir/resolved-device.txt"
  if resolve_install_device >"$resolved_device_file"; then
    INSTALL_DEVICE_ID="$(sed -n '1p' "$resolved_device_file")"
    resolved_device_name="$(sed -n '2p' "$resolved_device_file")"
    resolved_device_transport="$(sed -n '3p' "$resolved_device_file")"
    resolved_device_pairing="$(sed -n '4p' "$resolved_device_file")"
    printf 'Resolved iPhone install target: %s over %s (%s), install id %s\n' \
      "$resolved_device_name" \
      "$resolved_device_transport" \
      "$resolved_device_pairing" \
      "$(mask_id "$INSTALL_DEVICE_ID")"
  else
    INSTALL_DEVICE_ID="$DEVICE_ID"
    printf 'Could not resolve a paired devicectl target; falling back to DEVICE_ID %s\n' "$(mask_id "$DEVICE_ID")" >&2
  fi
else
  printf 'Using explicit INSTALL_DEVICE_ID %s\n' "$(mask_id "$INSTALL_DEVICE_ID")"
fi

install_workspace="$temp_dir/app-only-install"
mkdir -p "$install_workspace"
cp -R "$PROJECT_PATH" "$install_workspace/Whoordan.xcodeproj"
for path in \
  Whoordan \
  WhoordanTests \
  WhoordanUITests
do
  if [[ -e "$ROOT_DIR/$path" ]]; then
    ln -s "$ROOT_DIR/$path" "$install_workspace/$path"
  fi
done
app_only_info_plist="$install_workspace/WhoordanAppOnlyInfo.plist"
cp "$ROOT_DIR/Whoordan/Resources/Info.plist" "$app_only_info_plist"
/usr/libexec/PlistBuddy -c 'Delete :NSAccessorySetupBluetoothServices' "$app_only_info_plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Delete :NSAccessorySetupKitSupports' "$app_only_info_plist" >/dev/null 2>&1 || true
/usr/bin/python3 - "$install_workspace/Whoordan.xcodeproj/project.pbxproj" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
source = source.replace(
    "INFOPLIST_FILE = Whoordan/Resources/Info.plist;",
    "INFOPLIST_FILE = WhoordanAppOnlyInfo.plist;",
)
path.write_text(source, encoding="utf-8")
PY
build_project_path="$install_workspace/Whoordan.xcodeproj"
printf 'Using iPhone install build without AccessorySetupKit declarations.\n'

xcconfig="$temp_dir/whoordan-supabase.xcconfig"
{
  printf 'SUPABASE_PROJECT_ID = %s\n' "$PROJECT_ID"
  printf 'WHOORDAN_SUPABASE_PUBLISHABLE_KEY = %s\n' "$PUBLISHABLE_KEY"
  printf 'SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) WHOORDAN_APP_ONLY_INSTALL\n'
} >"$xcconfig"

build_args=(
  -project "$build_project_path"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "$DESTINATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -xcconfig "$xcconfig"
)

if [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
  build_args+=(-allowProvisioningUpdates)
fi

redact_supabase_output() {
  sed -E \
    -e 's/(SUPABASE_PROJECT_ID = ).*/\1[redacted]/' \
    -e 's/(WHOORDAN_SUPABASE_PUBLISHABLE_KEY = ).*/\1[redacted]/' \
    -e 's/(WHOORDAN_SUPABASE_URL = ).*/\1[redacted]/'
}

set +e
xcodebuild build "${build_args[@]}" 2>&1 | redact_supabase_output
build_status="${PIPESTATUS[0]}"
set -e
if [[ "$build_status" -ne 0 ]]; then
  if [[ "$ALLOW_PROVISIONING_UPDATES" != "1" ]]; then
    printf '\nBuild failed. If Xcode reports missing provisioning profiles and Ward has authorized Apple provisioning changes, rerun with:\n' >&2
    printf '  ALLOW_PROVISIONING_UPDATES=1 %s\n' "$0" >&2
  fi
  exit "$build_status"
fi

if [[ "$SKIP_INSTALL" == "1" ]]; then
  exit 0
fi

app_path="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphoneos/Whoordan.app"
if [[ ! -d "$app_path" ]]; then
  printf 'Built app was not found at %s\n' "$app_path" >&2
  exit 1
fi

xcrun devicectl device install app --device "$INSTALL_DEVICE_ID" "$app_path"
