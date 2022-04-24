#!/usr/bin/env python3

from setuptools import setup
from setuptools import find_packages


with open('requirements.txt') as f:
    req = f.read().splitlines()

with open('README.md') as f:
    long_desc = f.read().splitlines()

setup(
    name='vl-cli',
    version='1.0.0',
    description='CLI tool for loading and validating data',
    long_description=long_desc,
    long_description_content_type='text/markdown',
    author='Antonio Dumit',
    url='https://github.com/dumit98/projects/tree/master/vl-cli',
    packages=find_packages(),
    install_requires=req,
    entry_points={
        'console_scripts': [
            'vl = vl.vl:main'
        ],
    },
)
