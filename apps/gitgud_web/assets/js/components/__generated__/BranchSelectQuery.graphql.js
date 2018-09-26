/**
 * @flow
 * @relayHash aa25284477d733270ed0a4221175b791
 */

/* eslint-disable */

'use strict';

/*::
import type { ConcreteRequest } from 'relay-runtime';
export type GitReferenceType = "BRANCH" | "TAG" | "%future added value";
export type BranchSelectQueryVariables = {|
  repoID: string
|};
export type BranchSelectQueryResponse = {|
  +node: ?{|
    +refs?: ?{|
      +edges: ?$ReadOnlyArray<?{|
        +node: ?{|
          +oid: any,
          +name: string,
          +type: GitReferenceType,
          +url: string,
        |}
      |}>
    |}
  |}
|};
export type BranchSelectQuery = {|
  variables: BranchSelectQueryVariables,
  response: BranchSelectQueryResponse,
|};
*/


/*
query BranchSelectQuery(
  $repoID: ID!
) {
  node(id: $repoID) {
    __typename
    ... on Repo {
      refs(first: 100) {
        edges {
          node {
            oid
            name
            type
            url
          }
        }
      }
    }
    id
  }
}
*/

const node/*: ConcreteRequest*/ = (function(){
var v0 = [
  {
    "kind": "LocalArgument",
    "name": "repoID",
    "type": "ID!",
    "defaultValue": null
  }
],
v1 = [
  {
    "kind": "Variable",
    "name": "id",
    "variableName": "repoID",
    "type": "ID!"
  }
],
v2 = {
  "kind": "InlineFragment",
  "type": "Repo",
  "selections": [
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "refs",
      "storageKey": "refs(first:100)",
      "args": [
        {
          "kind": "Literal",
          "name": "first",
          "value": 100,
          "type": "Int"
        }
      ],
      "concreteType": "GitReferenceConnection",
      "plural": false,
      "selections": [
        {
          "kind": "LinkedField",
          "alias": null,
          "name": "edges",
          "storageKey": null,
          "args": null,
          "concreteType": "GitReferenceEdge",
          "plural": true,
          "selections": [
            {
              "kind": "LinkedField",
              "alias": null,
              "name": "node",
              "storageKey": null,
              "args": null,
              "concreteType": "GitReference",
              "plural": false,
              "selections": [
                {
                  "kind": "ScalarField",
                  "alias": null,
                  "name": "oid",
                  "args": null,
                  "storageKey": null
                },
                {
                  "kind": "ScalarField",
                  "alias": null,
                  "name": "name",
                  "args": null,
                  "storageKey": null
                },
                {
                  "kind": "ScalarField",
                  "alias": null,
                  "name": "type",
                  "args": null,
                  "storageKey": null
                },
                {
                  "kind": "ScalarField",
                  "alias": null,
                  "name": "url",
                  "args": null,
                  "storageKey": null
                }
              ]
            }
          ]
        }
      ]
    }
  ]
};
return {
  "kind": "Request",
  "operationKind": "query",
  "name": "BranchSelectQuery",
  "id": null,
  "text": "query BranchSelectQuery(\n  $repoID: ID!\n) {\n  node(id: $repoID) {\n    __typename\n    ... on Repo {\n      refs(first: 100) {\n        edges {\n          node {\n            oid\n            name\n            type\n            url\n          }\n        }\n      }\n    }\n    id\n  }\n}\n",
  "metadata": {},
  "fragment": {
    "kind": "Fragment",
    "name": "BranchSelectQuery",
    "type": "RootQueryType",
    "metadata": null,
    "argumentDefinitions": v0,
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "node",
        "storageKey": null,
        "args": v1,
        "concreteType": null,
        "plural": false,
        "selections": [
          v2
        ]
      }
    ]
  },
  "operation": {
    "kind": "Operation",
    "name": "BranchSelectQuery",
    "argumentDefinitions": v0,
    "selections": [
      {
        "kind": "LinkedField",
        "alias": null,
        "name": "node",
        "storageKey": null,
        "args": v1,
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
          {
            "kind": "ScalarField",
            "alias": null,
            "name": "id",
            "args": null,
            "storageKey": null
          },
          v2
        ]
      }
    ]
  }
};
})();
// prettier-ignore
(node/*: any*/).hash = 'e6e094ab10af760a93d51557201ca7bc';
module.exports = node;
