#!/bin/bash
# Auto-retry script to create Oracle Cloud ARM instance
# Retries every 60 seconds until capacity is available

OCI=/home/muttayyab/Desktop/RomaSub.Ai/venv/bin/oci
COMPARTMENT="ocid1.tenancy.oc1..aaaaaaaaysqwxa2cdosjdrm5ac7mi3dlxrgomggbbwblvo3culx7pujsrq2q"
AD="IfUh:AP-HYDERABAD-1-AD-1"
SUBNET="ocid1.subnet.oc1.ap-hyderabad-1.aaaaaaaaeuzgfh3ug6qhbwxs3gcqkfxczm2oxsevopproy4rrpv7j2iygryq"
IMAGE="ocid1.image.oc1.ap-hyderabad-1.aaaaaaaa3mza2sx62iglmjxihlck45nhb3hwxnyzqckcagjlbfzeibae4kra"
SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDYKQ6GAvF1CVEVSh/jxxOSpBVOtVlFIsUuVGKE37S8 romasub-oracle"

ATTEMPT=0

while true; do
    ATTEMPT=$((ATTEMPT + 1))
    echo ""
    echo "=== Attempt #$ATTEMPT at $(date) ==="

    RESULT=$($OCI compute instance launch \
        --compartment-id "$COMPARTMENT" \
        --availability-domain "$AD" \
        --shape "VM.Standard.A1.Flex" \
        --shape-config '{"ocpus": 4, "memoryInGigabytes": 24}' \
        --image-id "$IMAGE" \
        --subnet-id "$SUBNET" \
        --assign-public-ip true \
        --display-name "romasub-server" \
        --ssh-authorized-keys-file /home/muttayyab/.oci/romasub_ssh_key.pub \
        --boot-volume-size-in-gbs 150 \
        2>&1)

    if echo "$RESULT" | grep -q '"lifecycle-state"'; then
        echo ""
        echo "========================================="
        echo "  SUCCESS! Instance is being created!"
        echo "========================================="
        echo ""
        echo "$RESULT" | grep -E '"id"|"display-name"|"lifecycle-state"|"public-ip"'

        # Extract instance ID and wait for public IP
        INSTANCE_ID=$(echo "$RESULT" | grep '"id"' | head -1 | cut -d'"' -f4)
        echo ""
        echo "Instance ID: $INSTANCE_ID"
        echo "Waiting for public IP assignment..."
        sleep 60

        # Get the public IP
        VNIC_ATTACHMENTS=$($OCI compute vnic-attachment list \
            --compartment-id "$COMPARTMENT" \
            --instance-id "$INSTANCE_ID" \
            --query 'data[0]."vnic-id"' --raw-output 2>&1)

        PUBLIC_IP=$($OCI network vnic get \
            --vnic-id "$VNIC_ATTACHMENTS" \
            --query 'data."public-ip"' --raw-output 2>&1)

        echo ""
        echo "========================================="
        echo "  PUBLIC IP: $PUBLIC_IP"
        echo "========================================="
        echo ""
        echo "SSH command:"
        echo "  ssh -i /home/muttayyab/.oci/romasub_ssh_key ubuntu@$PUBLIC_IP"
        echo ""
        break
    else
        echo "Out of capacity. Retrying in 60 seconds..."
        echo "(Press Ctrl+C to stop)"
        sleep 60
    fi
done
