#!/bin/bash
#
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eox pipefail

# This is the entry point for the production deployment

# If any command returns with non-zero exit code, set -e will cause the script
# to exit. Prior to exit, set App assembly status to "Failed".
handle_failure() {
  code=$?
  patch_assembly_phase.sh --status="Failed"
  exit $code
}
trap "handle_failure" EXIT


/bin/expand_config.py
APP_INSTANCE_NAME="$(/bin/print_config.py --param '{"x-google-marketplace": {"type": "NAME"}}')"
NAMESPACE="$(/bin/print_config.py --param '{"x-google-marketplace": {"type": "NAMESPACE"}}')"

echo "Deploying application \"$APP_INSTANCE_NAME\""

application_uid=$(kubectl get "applications/$APP_INSTANCE_NAME" \
  --namespace="$NAMESPACE" \
  --output=jsonpath='{.metadata.uid}')

create_manifests.sh --application_uid="$application_uid"

# Ensure assembly phase is "Pending", until successful kubectl apply.
/bin/setassemblyphase.py \
  --manifest "/data/resources.yaml" \
  --status "Pending"

# Apply the manifest.
kubectl apply --namespace="$NAMESPACE" --filename="/data/resources.yaml"

patch_assembly_phase.sh --status="Success"

clean_iam_resources.sh

trap - EXIT