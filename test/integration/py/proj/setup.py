from setuptools import setup

try:
    version = open('version', 'r').read().strip()
except IOError:
    version = '9999+dev'

if __name__ == "__main__":
    setup()
