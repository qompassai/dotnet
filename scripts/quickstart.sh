#!/usr/bin/env bash
# qompassai/dotnet/scripts/quickstart.sh
# Qompass AI Diver · .NET Quick-Start
# Copyright (C) 2025 Qompass AI
# --------------------------------------------------
set -euo pipefail
PREFIX="$HOME/.local"
BIN="$PREFIX/bin"
LIB="$PREFIX/lib/msbuild-ls"
MSBUILD_REPO="https://github.com/tintoy/msbuild-project-tools-server.git"
JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu || echo 4)
declare -A DOTNET_VERSIONS=(
	[1]="8.0 LTS"
	[2]="7.0"
	[3]="6.0 LTS"
	[4]="5.0 (Legacy)"
	[5]="Latest (preview)"
)
declare -A DOTNET_CHANNELS=(
	[1]="8.0"
	[2]="7.0"
	[3]="6.0"
	[4]="5.0"
	[5]="preview"
)
echo -e "\n╭─────────────────────────────────────────────╮"
echo "│     Qompass AI · .NET Quick-Start Installer │"
echo "╰─────────────────────────────────────────────╯"
echo "        © 2025 Qompass AI. All rights reserved"
echo
for k in "${!DOTNET_VERSIONS[@]}"; do
	echo " $k) ${DOTNET_VERSIONS[$k]}"
done
echo " a) all   (installs LTS + Preview)"
echo " q) quit"
echo
read -rp "Choose version(s) to install [1]: " choice
choice="${choice:-1}"
[[ $choice == q ]] && exit 0
chosen_channels=()
if [[ $choice == "a" ]]; then
	chosen_channels=("8.0" "6.0" "preview")
else
	for c in $choice; do
		if [[ -n "${DOTNET_CHANNELS[$c]:-}" ]]; then
			chosen_channels+=("${DOTNET_CHANNELS[$c]}")
		else
			echo "❌ Invalid selection: $c"
			exit 1
		fi
	done
fi
detect_os_arch() {
	OS=$(uname -s | tr '[:upper:]' '[:lower:]')
	ARCH=$(uname -m)
	case "$ARCH" in
	x86_64 | amd64) ARCH="x64" ;;
	aarch64 | arm64) ARCH="arm64" ;;
	*) ARCH="unsupported" ;;
	esac
}
need_tool() {
	command -v "$1" >/dev/null 2>&1
}
add_to_rc() {
	local line="export PATH='$HOME/.local/bin:$PATH'"
	[[ -f "$1" && ! "$(cat "$1")" == *"$line"* ]] &&
		echo -e "\n# added by dotnet quickstart\n$line" >>"$1"
}
setup_path() {
	[[ ":$PATH:" != *"$HOME/.local/bin"* ]] && export PATH="$HOME/.local/bin:$PATH"
	mkdir -p "$BIN"
	add_to_rc "$HOME/.bashrc"
	add_to_rc "$HOME/.zshrc"
}
install_dotnet_version() {
	local channel="$1"
	local install_dir="$HOME/.dotnet/$channel"
	echo "→ Installing .NET SDK $channel to $install_dir..."
	curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh
	bash /tmp/dotnet-install.sh --channel "$channel" --install-dir "$install_dir" --arch "$ARCH"
	export PATH="$install_dir:$PATH"
	ln -sf "$install_dir/dotnet" "$BIN/dotnet-$channel"
	[[ "$channel" == "8.0" ]] && ln -sf "$install_dir/dotnet" "$BIN/dotnet"
}
build_msbuild_lsp() {
	echo "→ Cloning MSBuild Project Tools Language Server..."
	git clone --depth=1 "$MSBUILD_REPO" /tmp/msbuild-ls
	mkdir -p "$LIB"
	pushd /tmp/msbuild-ls >/dev/null
	dotnet restore
	dotnet publish src/LanguageServer/LanguageServer.csproj -c Release -o "$LIB"
	popd >/dev/null && rm -rf /tmp/msbuild-ls
	echo "→ Creating msbuild-ls wrapper..."
	cat >"$BIN/msbuild-ls" <<EOF
#!/usr/bin/env bash
# /qompassai/dotnet/scripts/quickstart.sh
# Qompass AI MSBuild Language Server
# Copyright (C) 2025 Qompass AI, All rights reserved
####################################################
dotnet "\$HOME/.local/lib/msbuild-ls/MSBuildProjectTools.LanguageServer.Host.dll" "\$@"
EOF
	chmod +x "$BIN/msbuild-ls"
}
main() {
	detect_os_arch
	echo "Detected OS: $OS — Arch: $ARCH"
	for t in curl git; do
		need_tool "$t" || {
			echo "❌ Required tool not found: $t"
			exit 1
		}
	done
	setup_path
	for version in "${chosen_channels[@]}"; do
		install_dotnet_version "$version"
	done
	build_msbuild_lsp
	echo -e "\n✔ MSBuild Language Server installed as: $BIN/msbuild-ls"
	echo "➜ Add this to your Neovim config:"
	echo "    cmd = { 'msbuild-ls' }"
	echo -e "✅ Done. Run \`source ~/.bashrc\` or \`source ~/.zshrc\` or restart your terminal.\n"
}
main "$@"
