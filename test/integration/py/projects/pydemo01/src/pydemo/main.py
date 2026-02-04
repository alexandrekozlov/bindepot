from requests import get

def main():
    print("pydemo is running...")
    print("GET https://example.com →", get("https://example.com").status_code)

if __name__ == "__main__":
    main()
