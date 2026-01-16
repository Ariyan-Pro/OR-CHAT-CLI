class Orchat < Formula
  desc "ORCHAT Enterprise AI Assistant"
  homepage "https://orchat.ai"
  url "https://github.com/orchat/enterprise/archive/v0.8.0.tar.gz"
  sha256 "to_be_calculated"
  license "MIT"

  depends_on "curl"
  depends_on "jq"
  depends_on "python@3.12"

  def install
    # Install binary
    bin.install "bin/orchat"
    
    # Install libraries
    libexec.install "src"
    
    # Install documentation
    doc.install "docs"
    
    # Create wrapper script
    (bin/"orchat").write <<~EOS
      #!/bin/bash
      export ORCHAT_HOME="#{libexec}"
      exec "#{libexec}/bootstrap.sh" "$@"
    EOS
  end

  test do
    system "#{bin}/orchat", "--version"
  end
end
