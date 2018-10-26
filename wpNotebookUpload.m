(* Mathematica Package         *)
(* Created by IntelliJ IDEA    *)

(* :Title: wp-notebook *)
(* :Context: wp-notebook` *)
(* :Author: Calle Ekdahl *)
(* :Date: 2016-07-06 *)

(* :Package Version: 1.0 *)
(* :Mathematica Version: 10.0 *)
(* :License: GPL-2.0+ *)
(* :Keywords:  WordPress, notebooks *)
(* :Discussion: Converts notebooks into suitable HTML and uploads it to WordPress. *)

BeginPackage["wp`wpNotebookUpload`", {"wp`"}]

uploadNotebook::usage = "uploadNotebook[nb_String, fields_Association] creates a new post by converting the content of
the notebook with file path nb to WordPress suitable HTML. fields can be used to provide parameters such as post_type,
look up the XML-RPC newPost method in WordPress documentation for full information.\n
uploadNotebook[nb_String, id_Integer, fields_Association] works like the previous function excepts it updates an
existing post with ID id."

convertNotebook::usage = "convertNotebook[nb] converts the notebook nb to WordPress suitable HTML. nb can be either a file path or a notebook object."

getInputExpressionString::usage = "getInputExpressionString[expr] copies the cell expressions corresponding to input cells in expr to the clipboard."

Begin["`Private`"] (* Begin Private Context *)

Needs["JLink`"];
InstallJava[];
LoadJavaClass["java.awt.Toolkit", AllowShortContext -> False];
LoadJavaClass["java.awt.datatransfer.DataFlavor", AllowShortContext -> False];

getClipboardString[] := JavaBlock@Module[{clipboard, flavor},
          clipboard = java`awt`Toolkit`getDefaultToolkit[]@getSystemClipboard[];
          flavor = java`awt`datatransfer`DataFlavor`stringFlavor;
          If[
            clipboard@isDataFlavorAvailable[flavor],
            clipboard@getData[flavor],
            $Failed
          ]
]

parseTextData::unrecognized = "An unsupported text element was ignored.";
parseCell::uninterpreted = "An unsupported type of cell was ignored.";
uploadRasterizedExpression::error = "Could not upload graphics to WordPress.";
convertNotebook::notebook = "Could not open the specified notebook."

hexifyColor[color_RGBColor] := StringJoin["#", IntegerString[Round[255 Level[color, 1]], 16, 2]]

Options[parseCell] = {
  "InputOpen" -> "<pre class='inputCell'><code>",
  "InputClose" -> "</code></pre>",
  "OutputOpen" -> "<pre class='outputCell'><code>",
  "OutputClose" -> "</code></pre>",
  "RasterizeCode" -> True,
  "GroupCodeBlocks" -> True,
  "PageWidth" -> 650
};

parseCell[___][Cell[text_String, "Title", ___]] := StringJoin["<h1>", text, "</h1>"]
parseCell[___][Cell[text_String, "Subtitle", ___]] := StringJoin["<h2>", text, "</h2>"]
parseCell[___][Cell[text_String, "Subsubtitle", ___]] := StringJoin["<h3>", text, "</h3>"]
parseCell[___][Cell[text_String, "Section", ___]] := StringJoin["<h4>", text, "</h4>"]
parseCell[___][Cell[text_String, "Subsection", ___]] := StringJoin["<h5>", text, "</h5>"]
parseCell[___][Cell[text_String, "Subsubsection", ___]] := StringJoin["<h6>", text, "</h6>"]
parseCell[___][Cell[text_String, "Text", ___]] := StringJoin["<p>", text, "</p>"]
parseCell[___][Cell[TextData[text_], "Text", ___]] := parseTextData[text]
parseCell[___][Cell[TextData[text_List], "Text", ___]] := StringJoin[parseTextData /@ text]
parseCell[___][gr : Cell[BoxData[_GraphicsBox], ___]] := With[{img = uploadRasterizedExpression["notebook-graphics.png", gr]},
  If[
    img === $Failed,
    "",
    StringJoin["<img src=\"", img["url"], "\" />"]
    ]
]
parseCell[___][Cell[text_String, "Quote"]] := StringJoin["<blockquote>", text, "</blockquote>"]
parseCell[___][Cell[_, "HLine"]] := "<hr />"
parseCell[___][Cell[CellGroupData[cells_List, _]]] := parseCell /@ cells
parseCell[___][c_] := (Echo[c]; Message[parseCell::uninterpreted]; "")

parseCell[opts: OptionsPattern[]][input: Cell[_BoxData, "Output", ___]] /; OptionValue[parseCell, {opts}, "RasterizeCode"] := With[
  {img = uploadRasterizedExpression["notebook-graphics.png", input]},
  If[
    img === $Failed,
    "",
    StringJoin["<img src=\"", img["url"], "\" />"]
  ]
]
parseCell[opts: OptionsPattern[]][gr: Cell[_BoxData, "Input", ___]] /; OptionValue[parseCell, {opts}, "RasterizeCode"] := Module[{img},
  img = uploadRasterizedExpression["notebook-graphics.png", gr, "PageWidth" -> OptionValue[parseCell, {opts}, "PageWidth"]];
  If[img === $Failed, Return[""]];
  StringJoin[
    "<div class=\"notebook-expression\">\n",
    "<img src=\"", img["url"], "\" />\n",
    "<textarea style=\"display: none;\">",
    (* ToString[Flatten@{extractInput[gr]}, InputForm], *)
    getInputExpressionString[gr],
    "</textarea>\n</div>\n"
  ]
]

parseCell[opts: OptionsPattern[]][input: Cell[_BoxData, "Input", ___]] := StringJoin[
  OptionValue[parseCell, {opts}, "InputOpen"],
  First@FrontEndExecute[FrontEnd`ExportPacket[input, "InputText"]],
  OptionValue[parseCell, {opts}, "InputClose"]
]
parseCell[opts: OptionsPattern[]][output: Cell[_BoxData, "Output", ___]] := StringJoin[
  OptionValue[parseCell, {opts}, "OutputOpen"],
  First@FrontEndExecute[FrontEnd`ExportPacket[output, "InputText"]],
  OptionValue[parseCell, {opts}, "OutputClose"]
];

inout = Cell[CellGroupData[{
  Cell[_, "Input", ___],
  Alternatives[
    Cell[_, "Output", ___],
    Cell[CellGroupData[{
      Cell[_, "Print", ___] ..
    }, _]]
  ]
}, _]];

(* extractInput[cells_] := Cases[cells, Cell[_, "Input", ___], Infinity] *)

parseCell[opts: OptionsPattern[]][gr: (inout | {inout..})] /; OptionValue[parseCell, {opts}, "RasterizeCode"] := Module[{img},
  img = uploadRasterizedExpression["notebook-graphics.png", gr, "PageWidth" -> OptionValue[parseCell, {opts}, "PageWidth"]];
  If[img === $Failed, Return[""]];
  StringJoin[
    "<div class=\"notebook-expression\">\n",
    "<img src=\"", img["url"], "\" />\n",
    "<textarea style=\"display: none;\">",
    (* ToString[Flatten@{extractInput[gr]}, InputForm], <--- This did not deal with new lines correctly *)
    getInputExpressionString[gr],
    "</textarea>\n</div>\n"
  ]
]

getInputExpressionString[expr_] := Module[{input, nb},
  input = Cases[Flatten@{expr}, Cell[_, "Input", ___], Infinity];
  nb = CreateDocument[input, Visible -> False]; (* Visibility has to be true *)
  SelectionMove[nb, All, Notebook];
  FrontEndExecute[FrontEndToken[nb, "CopySpecial", "CellExpression"]];
  NotebookClose[nb];
  getClipboardString[]
]

parseTextData[el_StyleBox] := Fold[addStyle, el]
parseTextData[ButtonBox[text_String, BaseStyle -> "Hyperlink", ButtonData -> {URL[url_String], ___}, ___]] := StringJoin[{"<a href=\"", url, "\">", text, "</a>"}]
parseTextData[el_String] := el
parseTextData[el_] := (Message[parseTextData::unrecognized]; Nothing[])

addStyle[text_String, FontWeight -> "Bold"] := StringJoin["<strong>", text, "</strong>"]
addStyle[text_String, FontSlant -> "Italic"] := StringJoin["<em>", text, "</em>"]
addStyle[text_String, FontVariations -> {"Underline" -> True}] := StringJoin["<span style=\"text-decoration: underline;\">", text, "</span>"]
addStyle[text_String, FontColor -> color_RGBColor] := StringJoin["<span style=\"color: ", hexifyColor[color], "\">", text, "</span>"]
addStyle[text_String, _] := text

Options[uploadRasterizedExpression] = {
  "PageWidth" -> 650
};
uploadRasterizedExpression[fileName_, expr_, OptionsPattern[]] := Module[{nb, input, image, uploadedImage},
  nb = CreateDocument[{}, WindowSelected -> False, Visible -> False, WindowSize -> OptionValue["PageWidth"]];
  NotebookWrite[nb, expr];
  image = Rasterize[nb, "Image"];
  NotebookClose[nb];
  uploadedImage = uploadImage[fileName, image];
  If[
    uploadedImage === $Failed,
    Message[uploadRasterizedExpression::error]; $Failed,
    uploadedImage
  ]
]

Options[convertNotebook] = {
  "InputOpen" -> "<pre class='inputCell'><code>",
  "InputClose" -> "</code></pre>",
  "OutputOpen" -> "<pre class='outputCell'><code>",
  "OutputClose" -> "</code></pre>",
  "RasterizeCode" -> True,
  "GroupCodeBlocks" -> True,
  "PageWidth" -> 650
};

convertNotebook[filePath_String, opts: OptionsPattern[]] := With[{nb = NotebookOpen[filePath, Visible -> False]},
  If[nb === $Failed,
    Message[convertNotebook::notebook]; $Failed,
    convertNotebook[NotebookGet[nb], opts]
  ]
  NotebookClose[nb]
]

convertNotebook[Notebook[cells : {___Cell}, ___], opts: OptionsPattern[]] := StringRiffle[Flatten[Reap@convertNotebook1[opts]@cells~Part~2], "\n\n"]
convertNotebook1[opts: OptionsPattern[]][cells : {Except[inout] ..}] := convertNotebook1[opts] /@ cells
convertNotebook1[opts: OptionsPattern[]][cells : Except[{inout ..}]] /; MemberQ[cells, inout] := convertNotebook1[opts] /@ SplitBy[cells, MatchQ[inout]]
convertNotebook1[opts: OptionsPattern[]][group : inout] := Sow[parseCell[opts][group]]
convertNotebook1[opts: OptionsPattern[]][group : {inout ..}] /; OptionValue[convertNotebook, {opts}, "GroupCodeBlocks"] := Sow[parseCell[opts][group]]
convertNotebook1[opts: OptionsPattern[]][group : {inout ..}] /; ! OptionValue[convertNotebook, {opts}, "GroupCodeBlocks"] := convertNotebook1[opts] /@ group
convertNotebook1[opts: OptionsPattern[]][cell: Cell[_, _, ___]] := Sow[parseCell[opts][cell]]
convertNotebook1[opts: OptionsPattern[]][Cell[CellGroupData[group_, _]]] := convertNotebook1[opts][group]

uploadNotebook[nb_, fields_Association: <||>, opts: OptionsPattern[]] := With[{html = convertNotebook[nb, opts]},
  If[html === $Failed,
    $Failed,
    newPost[<|<|
        "post_type" -> "post",
        "post_title" -> "",
        "post_content" -> html,
        "post_status" -> "publish"
        |>, fields|>] // ToExpression
  ]
]

uploadNotebook[nb_, id_Integer, fields_Association: <||>, opts: OptionsPattern[]] := Module[{html = convertNotebook[nb, opts]},
  If[html === $Failed,
    $Failed,
    editPost[id, <|<|
        "post_content" -> html
        |>, fields |>]
    ]
  ]

End[] (* End Private Context *)

EndPackage[]