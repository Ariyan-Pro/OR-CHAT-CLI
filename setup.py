from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="orchat-enterprise",
    version="0.8.0",
    author="ORCHAT Engineering",
    author_email="engineering@orchat.ai",
    description="ORCHAT Enterprise AI Assistant",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/orchat/enterprise",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Topic :: Scientific/Engineering :: Artificial Intelligence",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
    ],
    python_requires=">=3.8",
    install_requires=[
        "requests>=2.28.0",
        "tomli>=2.0.0",
    ],
    entry_points={
        "console_scripts": [
            "orchat=orchat.cli:main",
        ],
    },
)
