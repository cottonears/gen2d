const svg_pre_body =
    \\<!DOCTYPE html>
    \\<html lang="en">
    \\<head>
    \\    <meta charset="UTF-8" name="viewport" content="width=device-width, initial-scale=1.0"/>
    \\</head>
    \\<body>
;

const svg_post_body =
    \\</body>
    \\</html>
;

pub fn getCellSvgElements(pts: []@Vector(2, f32), fill: []u8) []u8 {
    _ = pts;
    _ = fill;
    const str = "<polygon points=\"50,0 20,50 80,50 65,80 35,80\" fill=\"#ADD8E6\"/>";
    return str;
}
