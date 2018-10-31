/**
 * @flow
 * @relayHash 6bd023705f4acc6ac9c7f1d9e75ec433
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
export type UserInputQueryVariables = {|
  input: string
|};
export type UserInputQueryResponse = {|
  +userSearch: ?{|
    +edges: ?$ReadOnlyArray<?{|
      +node: ?{|
        +id: string,
        +username: string,
        +name: ?string,
      |}
    |}>
  |}
|};
export type UserInputQuery = {|
  variables: UserInputQueryVariables,
  response: UserInputQueryResponse,
|};
*/


/*
query UserInputQuery(
  $input: String!
) {
  userSearch(input: $input, first: 10) {
    edges {
      node {
        id
        username
        name
      }
    }
  }
}
*/

const node/*: ConcreteRequest*/ = (function(){
var v0 = [
  {
    "kind": "LocalArgument",
    "name": "input",
    "type": "String!",
    "defaultValue": null
  }
],
v1 = [
  {
    "kind": "LinkedField",
    "alias": null,
    "name": "userSearch",
    "storageKey": null,
    "args": [
      {
        "kind": "Literal",
        "name": "first",
        "value": 10,
        "type": "Int"
      },
      {
        "kind": "Variable",
        "name": "input",
        "variableName": "input",
        "type": "String!"
      }
    ],
    "concreteType": "UserConnection",
    "plural": false,
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "edges",
        "storageKey": null,
        "args": null,
        "concreteType": "UserEdge",
        "plural": true,
        "selections": [
          {
            "kind": "LinkedField",
            "alias": null,
            "name": "node",
            "storageKey": null,
            "args": null,
            "concreteType": "User",
            "plural": false,
            "selections": [
              {
                "kind": "ScalarField",
                "alias": null,
                "name": "id",
                "args": null,
                "storageKey": null
              },
              {
                "kind": "ScalarField",
                "alias": null,
                "name": "username",
                "args": null,
                "storageKey": null
              },
              {
                "kind": "ScalarField",
                "alias": null,
                "name": "name",
                "args": null,
                "storageKey": null
              }
            ]
          }
        ]
      }
    ]
  }
];
return {
  "kind": "Request",
  "operationKind": "query",
  "name": "UserInputQuery",
  "id": null,
  "text": "query UserInputQuery(\n  $input: String!\n) {\n  userSearch(input: $input, first: 10) {\n    edges {\n      node {\n        id\n        username\n        name\n      }\n    }\n  }\n}\n",
  "metadata": {},
  "fragment": {
    "kind": "Fragment",
    "name": "UserInputQuery",
    "type": "RootQueryType",
    "metadata": null,
    "argumentDefinitions": v0,
    "selections": v1
  },
  "operation": {
    "kind": "Operation",
    "name": "UserInputQuery",
    "argumentDefinitions": v0,
    "selections": v1
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = 'b3e7fb76823b61db44ec26deabc5d1ae';
module.exports = node;
