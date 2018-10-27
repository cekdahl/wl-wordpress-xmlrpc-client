(* Mathematica Package         *)
(* Created by IntelliJ IDEA    *)

(* :Title: wp-notebook *)
(* :Context: wp-notebook` *)
(* :Author: Calle Ekdahl *)
(* :Date: 2018-07-28 *)

(* :Package Version: 1.0 *)
(* :Mathematica Version: 10.4 *)
(* :License: GPL-2.0+ *)
(* :Keywords:  WordPress, notebooks *)
(* :Discussion: Converts notebooks into suitable HTML and uploads it to WordPress. *)

BeginPackage["wp`wpPalette`", {"wp`", "wp`wpNotebookUpload`"}]

WordPressPalette::usage = "Show the WordPress palette."

(* Have to expose these so that the palette notebook can use them *)
removeCredentials;
credentials;
settings;
verify;
previewImage;
rasterizeSelection;
screenHeight;
validPostID;
notebookSnapshot;
postNotebook;
goToPost;

Begin["`Private`"] (* Begin Private Context *)

removeCredentials[] := (
  PersistentValue["wpUsername", "Local"] = "";
  PersistentValue["wpPassword", "Local"] = "";
);

credentials[] := CreateDialog[
  DynamicModule[{
    wpEndpoint = PersistentValue["wpEndpoint", "Local"],
    wpUsername = PersistentValue["wpUsername", "Local"],
    wpPassword = PersistentValue["wpPassword", "Local"]
  },
    Column[{
      Pane["Endpoint", ImageMargins -> {{0, 0}, {0, 7.5}}],
      InputField[Dynamic[wpEndpoint], String, ImageSize -> 300],
      Pane["Username", ImageMargins -> {{0, 0}, {0, 7.5}}],
      InputField[Dynamic[wpUsername], String, ImageSize -> 300],
      Pane["Password", ImageMargins -> {{0, 0}, {0, 7.5}}],
      InputField[Dynamic[wpPassword], String, ImageSize -> 300, FieldMasked -> True],
      Row[{
        Button["Verify", verify[wpEndpoint, wpUsername, wpPassword], ImageSize -> 150],
        Button[
          "Save",
          PersistentValue["wpEndpoint", "Local"] = wpEndpoint;
          PersistentValue["wpUsername", "Local"] = wpUsername;
          PersistentValue["wpPassword", "Local"] = wpPassword;
          SetWordPressCredentials[wpUsername, wpPassword, wpEndpoint];
          DialogReturn[],
          ImageSize -> 150
        ]
      }]
    }]
  ],
  WindowTitle -> "WordPress credentials", Background -> White
];

settings[] := CreateDialog[
  DynamicModule[{
    mathematicaToolbox = PersistentValue["wpMathematicaToolbox", "Local"] /. _Missing -> False,
    codeAppearance = PersistentValue["wpRasterizeCode", "Local"] /. _Missing -> Null,
    groupCodeBlocks = PersistentValue["wpGroupCodeBlocks", "Local"] /. _Missing -> True,
    pageWidth = PersistentValue["wpPageWidth", "Local"] /. _Missing -> Null
  },
    Column[{
      Pane["Code appearance", ImageMargins -> {{0, 0}, {0, 7.5}}],
      RadioButtonBar[
        Dynamic[codeAppearance],
        {True -> "Image", False -> "Text"},(* RasterizeCode option value *)
        Appearance -> "Horizontal"
      ],
      Pane["Mathematica Toolbox text code highlighting", ImageMargins -> {{0, 0}, {0, 7.5}}],
      RadioButtonBar[
        Dynamic[mathematicaToolbox],
        {True -> "On", False -> "Off"},
        Appearance -> "Horizontal"
      ],
      Pane["Group code blocks", ImageMargins -> {{0, 0}, {0, 7.5}}],
      RadioButtonBar[
        Dynamic[groupCodeBlocks],
        {True -> "Yes", False -> "No"},
        Appearance -> "Horizontal"
      ],
      Pane["Page width", ImageMargins -> {{0, 0}, {0, 7.5}}],
      InputField[Dynamic[pageWidth], Number, ImageSize -> 300],
      Row[{
        Spacer[150],
        Button[
          "Save",
          PersistentValue["wpMathematicaToolbox", "Local"] = mathematicaToolbox;
          PersistentValue["wpRasterizeCode", "Local"] = codeAppearance;
          PersistentValue["wpGroupCodeBlocks", "Local"] = groupCodeBlocks;
          PersistentValue["wpPageWidth", "Local"] = pageWidth;
          DialogReturn[],
          ImageSize -> 150
        ]
      }]
    }]
  ],
  WindowTitle -> "Settings", Background -> White
];

verify[wpEndpoint_, wpUsername_, wpPassword_] := Module[{hello, blogs},
  hello = Quiet@SendRequest["demo.sayHello", {}];
  blogs = Quiet@SendRequest["wp.getUsersBlogs", {wpUsername, wpPassword}];
  Which[
    hello =!= "Hello!",
    CreateDialog[{
      TextCell["Could not connect to endpoint " <> wpEndpoint],
      DefaultButton[]
    }],
    ! MatchQ[blogs, {__Association}],
    CreateDialog[{TextCell["Incorrect username or password."], DefaultButton[]}],
    True,
    CreateDialog[{
      TextCell["Succesfully connected to " <> First[blogs]["blogName"]],
      DefaultButton[]
    }]
  ];
];

getCurrentUser[] := With[{user = Quiet@getProfile[]}, If[
  AssociationQ[user],
  user["username"],
  "None"
]];

previewImage[expr_, img_] := CreateDialog[
  DynamicModule[{filename = "notebook-graphics.png", uploadedImage, inputMarkup, row},
    Column[{
      TextCell["Code for HTML embedding will be written to clipboard."],
      Pane[
        Image[img, Magnification -> 1],
        {Automatic, Min[screenHeight[] - 140, 1 + ImageDimensions[img][[2]]]},
        Scrollbars -> Automatic,
        AppearanceElements -> {},
        ImageMargins -> {{0, 0}, {10, 0}}
      ],
      TextCell["Filename (.png or .jpg)"],
      InputField[Dynamic[filename], String],
      Row[{Checkbox[Dynamic[inputMarkup]], "Make input copyable"}],
      Item[Button[
        "Upload",
        uploadedImage = uploadImage[filename, img];
        If[
          uploadedImage === $Failed,
          Print["Failed"];
          Beep[];
          CreateDialog[{
            TextCell[{"Failed to upload the image to WordPress."}],
            DefaultButton[]
          }],
          Print["Success"];
          If[
            inputMarkup,
            CopyToClipboard@StringJoin[
              "<div class=\"notebook-expression\">\n",
              "<img src=\"", uploadedImage["url"], "\" />\n",
              "<textarea style=\"display: none;\">",
              getInputExpressionString[expr],
              "</textarea>\n</div>\n"
            ];
            DialogReturn[],
            CopyToClipboard@StringJoin["<img src=\"", uploadedImage["url"], "\" />"];
            DialogReturn[]
          ]
        ];,
        ImageSize -> 150
      ], Alignment -> Right]
    }],
    WindowTitle -> "Image preview"
  ]
]
previewImage[$Failed] := Beep[]

rasterizeSelection[] := Module[{target, selection, image},
  selection = NotebookRead[SelectedNotebook[]];
  If[
    MemberQ[Hold[{}, $Failed, NotebookRead[$Failed]], selection],
    $Failed,
    target = CreateDocument[{},
      WindowSelected -> False,
      Visible -> False,
      WindowSize -> PersistentValue["wpPageWidth", "Local"]
    ];
    NotebookWrite[target, selection];
    image = Rasterize[target, "Image"];
    NotebookClose[target];
    image
  ]
];

screenHeight[] := -Subtract @@ Part[ScreenRectangle /. Options[$FrontEnd, ScreenRectangle], 2];

validPostID[id_] := With[{post = Quiet@getPost[id]}, And[
  ! MatchQ[post, $Failed],
  MemberQ[{"page", "post"}, post["post_type"]]
]]

notebookSnapshot[nbObject_, maxNumberOfCells_: Infinity] := Module[{cells},
      cells = NotebookRead /@ Take[Cells[nbObject], UpTo[maxNumberOfCells]];
      Rasterize[
        CreateDocument[cells, WindowSelected -> False, Visible -> False],
        "Image", ImageSize -> 600,
        ImageFormattingWidth -> 600
      ]
    ]

postNotebook[nb_, nbObject_, currentUser_] := CreateDialog[DynamicModule[{
    types = Complement[Keys[getPostTypes[]], {
      "attachment", "revision", "nav_menu_item", "custom_css",
      "customize_changeset", "oembed_cache", "user_request"
    }],
    users, title, type, status, user, id, target, targetField, post,
    content
  },
    users = #"user_id" -> #username & /@ getUsers[];
    If[
      ! MatchQ[CurrentValue[nbObject, {TaggingRules, "wpPostID"}], Inherited],
      targetField = ToString@CurrentValue[nbObject, {TaggingRules, "wpPostID"}];
      target = ToExpression[targetField];
      post = getPost[target];
      title = post["post_title"];
      type = post["post_type"];
      user = post["post_author"];
      status = post["post_status"];
      ,
      title = "";
      type = "post";
      status = "draft";
      user == (currentUser /. Reverse /@ users);
      target = None;
      targetField = Null;
    ];

  Column[{
    Pane[
      ImageCrop[notebookSnapshot[nbObject, 5], {Full, 200}, Bottom],
      ImageSize -> 300
    ],
    Dynamic[
      Pane[
        "Target: " <> If[target === None, "None", ToString[target]],
        ImageMargins -> {{0, 0}, {0, 7.5}}
      ],
      TrackedSymbols :> {target}],
    Row[{
      InputField[Dynamic[targetField], String, ImageSize -> 150],
      Button[
        "Set target",
        If[
          targetField == "",
          target = None,
          If[
            validPostID[ToExpression[targetField]],
            target = ToExpression[targetField];
            post = getPost[target];
            title = post["post_title"];
            type = post["post_type"];
            user = post["post_author"];
            status = post["post_status"];
            ,
            Beep[]
          ]
        ],
        ImageSize -> 150
      ]
    }],
    Pane["Post title", ImageMargins -> {{0, 0}, {0, 7.5}}],
    InputField[Dynamic[title], String, ImageSize -> 300],
    Pane["Post type", ImageMargins -> {{0, 0}, {0, 7.5}}],
    PopupMenu[Dynamic[type], types, ImageSize -> 300],
    Pane["Post status", ImageMargins -> {{0, 0}, {0, 7.5}}],
    PopupMenu[
      Dynamic[status], {"publish" -> "Published", "draft" -> "Draft"},
      ImageSize -> 300
    ],
    Pane["Post as user", ImageMargins -> {{0, 0}, {0, 7.5}}],
    PopupMenu[Dynamic[user], users, ImageSize -> 300],
    Row[{
      Spacer[150],
      Button[
        "Post notebook",
        content = <|
            "post_title" -> title,
            "post_content" -> If[

              PersistentValue["wpMathematicaToolbox", "Local"] /. _Missing -> False,
              convertNotebook[nb,
                "InputOpen" -> "[wlcode]",
                "InputClose" -> "[/wlcode]",
                "RasterizeCode" -> PersistentValue["wpRasterizeCode", "Local"] /. _Missing -> True,
                "GroupCodeBlocks" -> PersistentValue["wpGroupCodeBlocks", "Local"] /. _Missing -> True,
                "PageWidth" -> PersistentValue["wpPageWidth", "Local"] /. _Missing -> True
              ],
              convertNotebook[nb]
            ],
            "post_type" -> type,
            "post_author" -> user,
            "post_status" -> status
            |>;
        If[
          target === None,
          id = newPost[content],
          editPost[target, content];
          id = target
        ];
        CurrentValue[nbObject, {TaggingRules, "wpPostID"}] = id;
        goToPost[id];
        DialogReturn[],
        ImageSize -> 150
      ]
    }]
  }], Initialization :> (Needs["wp`wpPalette`"];)
  ], WindowTitle -> "Post notebook"
]

goToPost[id_String | id_Integer] := With[{post = getPost[ToExpression[id]]}, SystemOpen[post["link"]]]

WordPressPalette[] := CreateWindow@PaletteNotebook[
  DynamicModule[{wpCurrentUser = ""},
    Pane[Column[{
      ImageResize[Import["./Resources/wordpress-logo.jpg"], 160],
      Framed[Column[{
        Row[{Dynamic[
          Style["Current user:\n" <> wpCurrentUser,
            FontSize -> 12]]}, ImageSize -> 140],
        Row[{
          Tooltip[
            Button[Style["Remove credentials", FontSize -> 12],
              Block[{$ContextPath}, Needs["wp`wpPalette`"]; removeCredentials[]; wpCurrentUser = "None"],
              ImageSize -> 140],
            "Remove stored credentials.",
            TooltipDelay -> Automatic
          ]
        }]
      }]],
      Pane[OpenerView[{
        Style["Uploading", FontSize -> 14],
        Column[{
          Button[
            "Image",
            Block[{$ContextPath}, Needs["wp`wpPalette`"]; previewImage[NotebookRead[SelectedNotebook[]], rasterizeSelection[]]],
            Tooltip -> "Upload the selected expression as an image.",
            TooltipDelay -> Automatic, ImageSize -> 140
          ],
          Button[
            "Notebook",
            Block[{$ContextPath}, Needs["wp`wpPalette`"]; postNotebook[NotebookGet[], SelectedNotebook[], wpCurrentUser]],
            Tooltip -> "Transform the selected notebook into HTML and upload it as a blog post.",
            TooltipDelay -> Automatic, ImageSize -> 140
          ]
        }]
      }, True], ImageMargins -> {{0, 0}, {5, 5}}],
      OpenerView[{
        Style["Miscellaneous", FontSize -> 14],
        Column[{
          Button[
            "Settings",
            Block[{$ContextPath}, Needs["wp`wpPalette`"]; settings[]],
            Tooltip -> "Settings affecting how the uploading functions behave.",
            TooltipDelay -> Automatic, ImageSize -> 140
          ],
          Button["Credentials", Block[{$ContextPath}, Needs["wp`wpPalette`"]; credentials[]; wpCurrentUser = getCurrentUser[]],
            Tooltip -> "Set login credentials used to connect to WordPress.",
            TooltipDelay -> Automatic, ImageSize -> 140
          ],
          Button[
            "About",
            SystemOpen["https://github.com/cekdahl/wl-wordpress-xmlrpc-client"],
            Tooltip -> "Go to this package's Github page.",
            TooltipDelay -> Automatic, ImageSize -> 140
          ]
        }]
      }, True]
    },
      Background -> White
    ], Initialization :> (Needs["wp`wpPalette`"];)
    ],
    ImageMargins -> {{5, 5}, {5, 5}},
    Initialization :> (
      Needs["wp`wpPalette`"];
      SetWordPressCredentials[
        PersistentValue["wpUsername", "Local"],
        PersistentValue["wpPassword", "Local"],
        PersistentValue["wpEndpoint", "Local"]
      ];
      wpCurrentUser = getCurrentUser[];
    )
  ],
    Background -> White,
    WindowTitle -> "WordPress"
]

End[]
EndPackage[]