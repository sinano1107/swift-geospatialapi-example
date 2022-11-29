.PHONY: inject-api-key

inject-api-key:
	echo "// Enter your ARCore API key here\nlet apiKey = \"${API_KEY}\"" > ./SwiftGeospatial/APIKey.swift