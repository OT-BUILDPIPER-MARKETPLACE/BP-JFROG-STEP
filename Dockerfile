FROM releases-docker.jfrog.io/jfrog/jfrog-cli-v2-jf:latest

# Install dependencies
RUN apk add --no-cache zip tar curl bash wget jq

# Copy script and shell functions
COPY build.sh .
ADD BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/

# Set environment variables
ENV SLEEP_DURATION=5s \
    ACTIVITY_SUB_TASK_CODE=BP-JFROG-STEP \
    VALIDATION_FAILURE_ACTION=WARNING

# Entry point
ENTRYPOINT ["/bin/bash", "./build.sh"]
