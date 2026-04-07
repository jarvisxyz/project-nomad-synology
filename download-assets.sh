#!/bin/bash
#
# Project N.O.M.A.D. — Direct Asset Download Script
# Downloads Docker images and ZIM files directly without using the web UI
# Useful for air-gapped setups, batch pre-loading, or slow connections
#

set -euo pipefail

# Colors
RESET='\033[0m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'

# Base paths
STORAGE_DIR="${STORAGE_DIR:-/volume1/docker/project-nomad/storage}"
ZIM_DIR="$STORAGE_DIR/zim"
OLLAMA_DIR="$STORAGE_DIR/ollama"

# Docker images to pre-pull (optional services from the UI)
declare -A DOCKER_IMAGES=(
    ["kiwix"]="ghcr.io/kiwix/kiwix-serve:3.8.1"
    ["ollama"]="ollama/ollama:0.18.1"
    ["cyberchef"]="ghcr.io/gchq/cyberchef:10.22.1"
    ["flatnotes"]="dullage/flatnotes:v5.5.4"
    ["kolibri"]="treehouses/kolibri:0.12.8"
    ["qdrant"]="qdrant/qdrant:v1.16"
)

# ZIM collections with their URLs
# Format: "filename|url|size_mb|description"
declare -a ZIM_FILES=(
    # Medicine - Essential
    "zimgit-medicine_en_2024-08.zim|https://download.kiwix.org/zim/other/zimgit-medicine_en_2024-08.zim|67|Field and emergency medicine books"
    "nhs.uk_en_medicines_2025-12.zim|https://download.kiwix.org/zim/zimit/nhs.uk_en_medicines_2025-12.zim|16|NHS Medicines A to Z"
    "fas-military-medicine_en_2025-06.zim|https://download.kiwix.org/zim/zimit/fas-military-medicine_en_2025-06.zim|78|Tactical and field medicine manuals"
    "wwwnc.cdc.gov_en_all_2024-11.zim|https://download.kiwix.org/zim/zimit/wwwnc.cdc.gov_en_all_2024-11.zim|170|CDC Health Information"

    # Medicine - Standard (adds to Essential)
    "medlineplus.gov_en_all_2025-01.zim|https://download.kiwix.org/zim/zimit/medlineplus.gov_en_all_2025-01.zim|1800|MedlinePlus - NIH health encyclopedia"

    # Wikipedia tiers
    "wikipedia_en_top_mini_2025-12.zim|https://download.kiwix.org/zim/wikipedia/wikipedia_en_top_mini_2025-12.zim|200|Wikipedia Top Articles (Mini)"
    "wikipedia_en_top_nopic_2025-12.zim|https://download.kiwix.org/zim/wikipedia/wikipedia_en_top_nopic_2025-12.zim|600|Wikipedia Top Articles (No Pictures)"
    "wikipedia_en_all_mini_2025-12.zim|https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_mini_2025-12.zim|6000|Wikipedia All Articles (Mini)"

    # Preparedness
    "canadian_prepper_winterprepping_en_2026-02.zim|https://download.kiwix.org/zim/videos/canadian_prepper_winterprepping_en_2026-02.zim|140|Winter Prepping Videos"
    "canadian_prepper_bugoutroll_en_2025-08.zim|https://download.kiwix.org/zim/videos/canadian_prepper_bugoutroll_en_2025-08.zim|170|Bug Out Roll Videos"

    # Education
    "ted_mul_ted-ed_2026-01.zim|https://download.kiwix.org/zim/ted/ted_mul_ted-ed_2026-01.zim|3500|TED-Ed Educational Videos"
    "gutenberg_en_lcc-u_2026-03.zim|https://download.kiwix.org/zim/gutenberg/gutenberg_en_lcc-u_2026-03.zim|1600|Project Gutenberg Books"
)

# Print functions
print_header() {
    echo -e "${GREEN}========================================${RESET}"
    echo -e "${GREEN}  Project N.O.M.A.D. Asset Downloader${RESET}"
    echo -e "${GREEN}========================================${RESET}"
    echo ""
}

print_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running or you don't have permissions."
        print_info "Try: sudo bash $0"
        exit 1
    fi

    # Create directories
    mkdir -p "$ZIM_DIR" "$OLLAMA_DIR"

    print_success "Prerequisites check passed"
}

# Download a single ZIM file with resume support
download_zim() {
    local filename="$1"
    local url="$2"
    local size_mb="$3"
    local description="$4"
    local filepath="$ZIM_DIR/$filename"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    print_info "Downloading: $filename"
    print_info "Description: $description"
    print_info "Size: ~${size_mb} MB"

    if [[ -f "$filepath" ]]; then
        local existing_size=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null || echo "0")
        local expected_size=$((size_mb * 1024 * 1024))

        if [[ $existing_size -gt $((expected_size * 9 / 10)) ]]; then
            print_success "Already exists and looks complete (skipping)"
            return 0
        else
            print_warning "Partial file exists, resuming download..."
        fi
    fi

    # Download with curl (resume support, progress bar)
    if curl -C - -fSL --progress-bar \
        -o "$filepath" \
        -H "User-Agent: Project-NOMAD-Downloader/1.0" \
        "$url"; then
        print_success "Downloaded: $filename"
        return 0
    else
        print_error "Failed to download: $filename"
        return 1
    fi
}

# Pull a Docker image
pull_docker_image() {
    local name="$1"
    local image="$2"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    print_info "Pulling Docker image: $name"
    print_info "Image: $image"

    if docker image inspect "$image" &> /dev/null; then
        print_success "Image already exists locally: $image"
        return 0
    fi

    if docker pull "$image"; then
        print_success "Pulled: $image"
        return 0
    else
        print_error "Failed to pull: $image"
        return 1
    fi
}

# Download Ollama model
pull_ollama_model() {
    local model="$1"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    print_info "Pulling Ollama model: $model"

    # Check if Ollama container is running
    if docker ps --format '{{.Names}}' | grep -q "^nomad_ollama$"; then
        if docker exec nomad_ollama ollama pull "$model"; then
            print_success "Pulled Ollama model: $model"
            return 0
        else
            print_error "Failed to pull Ollama model: $model"
            return 1
        fi
    else
        print_warning "Ollama container not running. Model will be downloaded when service starts."
        print_info "To pre-download, start the Ollama service first via the NOMAD UI or:"
        print_info "  docker run --rm -v $OLLAMA_DIR:/root/.ollama ollama/ollama:0.18.1 pull $model"
        return 0
    fi
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

Download Docker images and ZIM files for Project N.O.M.A.D.
Useful for pre-loading assets on air-gapped or slow connections.

Commands:
  all                   Download everything (images + recommended ZIM files)
  images                Pull all optional Docker images only
  zim                   Download ZIM files only
  ollama <model>        Pull a specific Ollama model (e.g., llama3.2, qwen2.5)

Options:
  -d, --dir DIR         Set storage directory (default: /volume1/docker/project-nomad/storage)
  -c, --category CAT    Download specific ZIM category: medicine, wikipedia, preparedness, education, all
  --resume              Resume interrupted downloads (default behavior)
  -y, --yes             Skip confirmation prompts
  -h, --help            Show this help message

Examples:
  $0 all                           # Download everything
  $0 images                        # Pull Docker images only
  $0 zim -c medicine               # Download medical ZIM files
  $0 ollama llama3.2               # Pull llama3.2 model
  STORAGE_DIR=/custom/path $0 all  # Use custom storage path

EOF
}

# Confirm action
confirm() {
    local message="$1"
    if [[ "${SKIP_CONFIRM:-false}" == "true" ]]; then
        return 0
    fi
    echo ""
    read -p "$message [y/N] " -n 1 -r
    echo ""
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Main function
main() {
    local command=""
    local category="all"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            all|images|zim|ollama)
                command="$1"
                shift
                ;;
            -d|--dir)
                STORAGE_DIR="$2"
                ZIM_DIR="$STORAGE_DIR/zim"
                OLLAMA_DIR="$STORAGE_DIR/ollama"
                shift 2
                ;;
            -c|--category)
                category="$2"
                shift 2
                ;;
            -y|--yes)
                SKIP_CONFIRM=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                # For ollama command, treat remaining as model name
                if [[ "${command:-}" == "ollama" ]]; then
                    break
                fi
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    if [[ -z "$command" ]]; then
        usage
        exit 1
    fi

    print_header
    check_prerequisites

    case "$command" in
        all)
            print_info "Mode: Download all assets (Docker images + ZIM files)"
            echo "Storage directory: $STORAGE_DIR"
            echo ""

            if confirm "This will download several GB of data. Continue?"; then
                # Docker images
                for name in "${!DOCKER_IMAGES[@]}"; do
                    pull_docker_image "$name" "${DOCKER_IMAGES[$name]}" || true
                done

                # ZIM files
                for zim_entry in "${ZIM_FILES[@]}"; do
                    IFS='|' read -r filename url size_mb description <<< "$zim_entry"
                    download_zim "$filename" "$url" "$size_mb" "$description" || true
                done

                print_success "All downloads completed!"
            fi
            ;;

        images)
            print_info "Mode: Pull Docker images only"
            echo ""

            if confirm "Pull ${#DOCKER_IMAGES[@]} Docker images?"; then
                for name in "${!DOCKER_IMAGES[@]}"; do
                    pull_docker_image "$name" "${DOCKER_IMAGES[$name]}" || true
                done
                print_success "Docker images pulled!"
            fi
            ;;

        zim)
            print_info "Mode: Download ZIM files (category: $category)"
            echo "Storage directory: $ZIM_DIR"
            echo ""

            # Filter by category if specified
            local files_to_download=()
            for zim_entry in "${ZIM_FILES[@]}"; do
                IFS='|' read -r filename url size_mb description <<< "$zim_entry"

                # Simple category filtering based on filename/description
                local include=false
                case "$category" in
                    medicine)
                        [[ "$filename" =~ (medicine|medical|medline|cdc|nhs) ]] && include=true
                        ;;
                    wikipedia)
                        [[ "$filename" =~ wikipedia ]] && include=true
                        ;;
                    preparedness)
                        [[ "$filename" =~ prepper ]] && include=true
                        ;;
                    education)
                        [[ "$filename" =~ (ted|gutenberg|education) ]] && include=true
                        ;;
                    all)
                        include=true
                        ;;
                esac

                if [[ "$include" == "true" ]]; then
                    files_to_download+=("$zim_entry")
                fi
            done

            if [[ ${#files_to_download[@]} -eq 0 ]]; then
                print_error "No ZIM files found for category: $category"
                exit 1
            fi

            # Calculate total size
            local total_size=0
            for zim_entry in "${files_to_download[@]}"; do
                IFS='|' read -r filename url size_mb description <<< "$zim_entry"
                total_size=$((total_size + size_mb))
            done

            echo "Files to download: ${#files_to_download[@]}"
            echo "Total size: ~$((total_size / 1024)) GB"
            echo ""

            if confirm "Continue with download?"; then
                for zim_entry in "${files_to_download[@]}"; do
                    IFS='|' read -r filename url size_mb description <<< "$zim_entry"
                    download_zim "$filename" "$url" "$size_mb" "$description" || true
                done
                print_success "ZIM downloads completed!"
            fi
            ;;

        ollama)
            local model="${1:-llama3.2}"
            print_info "Mode: Pull Ollama model: $model"
            pull_ollama_model "$model"
            ;;

        *)
            print_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac

    echo ""
    echo -e "${GREEN}========================================${RESET}"
    echo -e "${GREEN}  Asset downloads complete!${RESET}"
    echo -e "${GREEN}========================================${RESET}"
}

# Run main function
main "$@"
