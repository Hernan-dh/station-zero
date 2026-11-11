# This project's environment: the base image plus the software and packages this game needs. The workspace and its task rollouts run on it, and restarting the project applies it. The Environment tab writes it from its software list and package list.
# gamerl:software godot
ARG BASE=gamerl-workspace:latest
FROM ${BASE}

# Godot, the native build for the machine: x86_64 or arm64. `godot` on PATH is the base's wrapper (image/gamerl-godot), which runs it under VirtualGL when VGL_DISPLAY is set. The workspace's web editor is the same release (the Dockerfile's GODOT_VERSION, which a test keeps equal to this one).
ARG GODOT_VERSION=4.7.2-stable
ENV GODOT_VERSION=${GODOT_VERSION}
RUN arch=$(case "$(dpkg --print-architecture)" in arm64) echo arm64 ;; *) echo x86_64 ;; esac) \
    && curl -fsSL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.${arch}.zip" \
    && rm -rf /opt/godot && unzip -q /tmp/godot.zip -d /opt/godot && rm /tmp/godot.zip \
    && godot --headless --version

# The Environment tab's package list. It rewrites the lines between these markers.
# gamerl:packages begin
# gamerl:packages end
