from __future__ import print_function
from googleapiclient.discovery import build
from httplib2 import Http
from oauth2client import file, client, tools

# From "Python Quickstart" page on Google Sheets API v4 webpage
# https://developers.google.com/sheets/api/quickstart/python?authuser=1


# If modifying these scopes, delete the file token.json.
SCOPES = 'https://www.googleapis.com/auth/spreadsheets.readonly'

# The ID and range of a sample spreadsheet.
SAMPLE_SPREADSHEET_ID = '14-j6QiyzX4oV378CgQhb6btfaaopbZTRXew1FxN1vag'
SAMPLE_RANGE_NAME = 'rna!A1:X'

def main():
	"""Shows basic usage of the Sheets API.
	Prints values from a sample spreadsheet.
	"""
	# The file token.json stores the user's access and refresh tokens, and is
	# created automatically when the authorization flow completes for the first
	# time.
	store = file.Storage('token.json')
	creds = store.get()
	if not creds or creds.invalid:
		flow = client.flow_from_clientsecrets('credentials.json', SCOPES)
		creds = tools.run_flow(flow, store)
	service = build('sheets', 'v4', http=creds.authorize(Http()))

	# Call the Sheets API
	sheet = service.spreadsheets()
	result = sheet.values().get(spreadsheetId=SAMPLE_SPREADSHEET_ID,
	                            range=SAMPLE_RANGE_NAME).execute()
	values = result.get('values', [])

	if not values:
	    print('No data found.')
	else:
	    for row in values:
		    # Print all columns in tsv format.
		    print(*row, sep='\t')

if __name__ == '__main__':
    main()
