# Disposable visual/installer checks. No services or device configuration are changed.
FROM traineros-ci:20260911
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xvfb xauth mesa-vulkan-drivers libgl1-mesa-dri && rm -rf /var/lib/apt/lists/*
