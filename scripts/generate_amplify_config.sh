#!/usr/bin/env bash
# Generate Amplify Cognito config for Android + iOS from env vars.
# Industry: public Cognito IDs only — NEVER Rekognition secret keys.
#
# Usage (from flutterapp_dating/ or with env file):
#   export COGNITO_IDENTITY_POOL_ID=us-east-1:xxxx
#   export COGNITO_USER_POOL_ID=us-east-1_XXXX   # optional
#   export COGNITO_APP_CLIENT_ID=xxxx             # optional
#   export COGNITO_REGION=us-east-1
#   ./scripts/generate_amplify_config.sh
#
# Or load backend .env:
#   set -a && source ../backend/datingapp/.env.prod && set +a
#   ./scripts/generate_amplify_config.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGION="${COGNITO_REGION:-${REKOGNITION_AWS_REGION:-us-east-1}}"
IDENTITY="${COGNITO_IDENTITY_POOL_ID:-}"
USER_POOL="${COGNITO_USER_POOL_ID:-}"
APP_CLIENT="${COGNITO_APP_CLIENT_ID:-}"

if [[ -z "$IDENTITY" ]]; then
  echo "ERROR: COGNITO_IDENTITY_POOL_ID is required."
  echo "Set it in backend .env and export before running this script."
  exit 1
fi

TMP="$(mktemp)"
if [[ -n "$USER_POOL" && -n "$APP_CLIENT" ]]; then
  cat >"$TMP" <<EOF
{
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify-cli/0.1.0",
        "Version": "0.1.0",
        "IdentityManager": { "Default": {} },
        "CredentialsProvider": {
          "CognitoIdentity": {
            "Default": {
              "PoolId": "${IDENTITY}",
              "Region": "${REGION}"
            }
          }
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "${USER_POOL}",
            "AppClientId": "${APP_CLIENT}",
            "Region": "${REGION}"
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH"
          }
        }
      }
    }
  }
}
EOF
else
  cat >"$TMP" <<EOF
{
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify-cli/0.1.0",
        "Version": "0.1.0",
        "IdentityManager": { "Default": {} },
        "CredentialsProvider": {
          "CognitoIdentity": {
            "Default": {
              "PoolId": "${IDENTITY}",
              "Region": "${REGION}"
            }
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH"
          }
        }
      }
    }
  }
}
EOF
fi

RAW_DIR="$ROOT/android/app/src/main/res/raw"
mkdir -p "$RAW_DIR"
cp "$TMP" "$RAW_DIR/amplifyconfiguration.json"
cp "$TMP" "$ROOT/ios/Runner/amplifyconfiguration.json"
cp "$TMP" "$ROOT/amplifyconfiguration.json"
# awsconfiguration.json (legacy native readers)
cp "$TMP" "$ROOT/ios/Runner/awsconfiguration.json" 2>/dev/null || true

rm -f "$TMP"
echo "Wrote Amplify config:"
echo "  - android/app/src/main/res/raw/amplifyconfiguration.json"
echo "  - ios/Runner/amplifyconfiguration.json"
echo "  - amplifyconfiguration.json"
echo "Region=$REGION IdentityPool=$IDENTITY"
echo "NOTE: In Xcode, ensure amplifyconfiguration.json is in the Runner target if not already."
