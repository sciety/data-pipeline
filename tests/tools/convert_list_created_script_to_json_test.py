from sciety_data_pipeline.tools.convert_list_created_script_to_json import (
    iter_parse_list_created_script_content_to_json
)


LIST_ID_1 = 'list0001-1111-1111-1111-111111111111'
LIST_ID_2 = 'list0002-1111-1111-1111-111111111111'

NAME_1 = 'Name 1'
NAME_2 = 'Name 2'

DESCRIPTION_1 = 'Description 1'
DESCRIPTION_2 = 'Description 2'

OWNER_ID_1 = 'owner001-1111-1111-1111-111111111111'
OWNER_ID_2 = 'owner002-1111-1111-1111-111111111111'

TIMESTAMP_1 = '2001-02-03T04:05:06Z'
TIMESTAMP_2 = '2001-02-03T04:05:06Z'


class TestParseListCreatedScriptContentToJson:
    def test_should_parse_multiple_list_created_events(self):
        js_script_content = (
            f'''
            export const listCreationEvents: ReadonlyArray<ListCreatedEvent> = [
            listCreated(
                LID.fromValidatedString('{LIST_ID_1}'),
                '{NAME_1}',
                '{DESCRIPTION_1}',
                GID.fromValidatedString('{OWNER_ID_1}'),
                new Date('{TIMESTAMP_1}'),
            ),
            listCreated(
                LID.fromValidatedString('{LIST_ID_2}'),
                '{NAME_2}',
                '{DESCRIPTION_2}',
                GID.fromValidatedString('{OWNER_ID_2}'),
                new Date('{TIMESTAMP_2}'),
            )
            ];
            '''
        )
        json_list = list(iter_parse_list_created_script_content_to_json(
            js_script_content
        ))
        assert json_list == [{
            'listId': LIST_ID_1
        }, {
            'listId': LIST_ID_2
        }]
