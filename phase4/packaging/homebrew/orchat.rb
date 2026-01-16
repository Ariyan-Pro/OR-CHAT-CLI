class Orchat < Formula
  desc "OpenRouter CLI with multi-turn chat and streaming"
  homepage "https://github.com/orchat/orchat"
  url "https://github.com/orchat/orchat/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "TODO: CALCULATE_ACTUAL_SHA256"
  license "MIT"

  depends_on "bash" => :required
  depends_on "python" => :recommended
  depends_on "jq" => :recommended
  depends_on "curl" => :required

  def install
    # Install binaries
    bin.install "bin/orchat"
    bin.install "bin/orchat.robust" => "orchat-robust"
    
    # Install modules
    libexec.install "src"
    
    # Install configuration
    etc.install "config/orchat.toml" => "orchat/orchat.toml"
    doc.install "config/schema.json"
    
    # Install data files
    pkgshare.install "data"
    
    # Create wrapper script with proper paths
    inreplace bin/"orchat", /SCRIPT_DIR=.*/, "SCRIPT_DIR=\"#{libexec}/src\""
  end

  def caveats
    <<~EOS
      ORCHAT has been installed!
      
      To get started:
      1. Set your OpenRouter API key:
         mkdir -p ~/.config/orchat
         echo 'your-api-key-here' > ~/.config/orchat/config
         chmod 600 ~/.config/orchat/config
      
      2. Test the installation:
         orchat "Hello from Homebrew!" --no-stream
      
      3. For interactive mode:
         orchat -i
      
      Optional dependencies:
      - python3: For advanced JSON handling and TOML parsing
      - jq: For JSON processing fallback
      
      Documentation: #{doc}
    EOS
  end

  test do
    # Test that help command works
    system "#{bin}/orchat", "--help"
    
    # Test config command
    system "#{bin}/orchat", "config", "list"
    
    # Test module loading
    assert_predicate libexec/"src/bootstrap.sh", :exist?
  end
end
