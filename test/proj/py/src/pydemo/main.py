from requests import get
import numpy as np

def main():
    print("pydemo is running...")
    print("GET https://example.com →", get("https://example.com").status_code)
    print("Random numpy number:", np.random.rand())

if __name__ == "__main__":
    main()
