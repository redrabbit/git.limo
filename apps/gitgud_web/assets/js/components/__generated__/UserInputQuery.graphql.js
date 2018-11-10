/**
 * @flow
 * @relayHash 0e9b33f64341e1d053a9d632b5df1d13
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
export type UserInputQueryVariables = {|
  input: string
|};
export type UserInputQueryResponse = {|
  +search: ?{|
    +edges: ?$ReadOnlyArray<?{|
      +node: ?{|
        +id?: string,
        +username?: string,
        +name?: ?string,
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
  search(user: $input, first: 10) {
    edges {
      node {
        __typename
        ... on User {
          id
          username
          name
        }
        ... on Node {
          id
        }
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
    "kind": "Literal",
    "name": "first",
    "value": 10,
    "type": "Int"
  },
  {
    "kind": "Variable",
    "name": "user",
    "variableName": "input",
    "type": "String"
  }
],
v2 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "id",
  "args": null,
  "storageKey": null
},
v3 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "username",
  "args": null,
  "storageKey": null
},
v4 = {
  "kind": "ScalarField",
  "alias": null,
  "name": "name",
  "args": null,
  "storageKey": null
};
return {
  "kind": "Request",
  "operationKind": "query",
  "name": "UserInputQuery",
  "id": null,
  "text": "query UserInputQuery(\n  $input: String!\n) {\n  search(user: $input, first: 10) {\n    edges {\n      node {\n        __typename\n        ... on User {\n          id\n          username\n          name\n        }\n        ... on Node {\n          id\n        }\n      }\n    }\n  }\n}\n",
  "metadata": {},
  "fragment": {
    "kind": "Fragment",
    "name": "UserInputQuery",
    "type": "RootQueryType",
    "metadata": null,
    "argumentDefinitions": v0,
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "search",
        "storageKey": null,
        "args": v1,
        "concreteType": "SearchResultConnection",
        "plural": false,
        "selections": [
          {
            "kind": "LinkedField",
            "alias": null,
            "name": "edges",
            "storageKey": null,
            "args": null,
            "concreteType": "SearchResultEdge",
            "plural": true,
            "selections": [
              {
                "kind": "LinkedField",
                "alias": null,
                "name": "node",
                "storageKey": null,
                "args": null,
                "concreteType": null,
                "plural": false,
                "selections": [
                  {
                    "kind": "InlineFragment",
                    "type": "User",
                    "selections": [
                      v2,
                      v3,
                      v4
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  },
  "operation": {
    "kind": "Operation",
    "name": "UserInputQuery",
    "argumentDefinitions": v0,
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "search",
        "storageKey": null,
        "args": v1,
        "concreteType": "SearchResultConnection",
        "plural": false,
        "selections": [
          {
            "kind": "LinkedField",
            "alias": null,
            "name": "edges",
            "storageKey": null,
            "args": null,
            "concreteType": "SearchResultEdge",
            "plural": true,
            "selections": [
              {
                "kind": "LinkedField",
                "alias": null,
                "name": "node",
                "storageKey": null,
                "args": null,
                "concreteType": null,
                "plural": false,
                "selections": [
                  {
                    "kind": "ScalarField",
                    "alias": null,
                    "name": "__typename",
                    "args": null,
                    "storageKey": null
                  },
                  v2,
                  {
                    "kind": "InlineFragment",
                    "type": "User",
                    "selections": [
                      v3,
                      v4
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = '73ed7926f4d17541f6cea7aa5120a7a3';
module.exports = node;
