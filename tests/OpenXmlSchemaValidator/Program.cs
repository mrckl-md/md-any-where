using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Validation;

if (args.Length != 1)
{
    Console.Error.WriteLine("Usage: OpenXmlSchemaValidator <document.docx>");
    return 2;
}

using var document = WordprocessingDocument.Open(args[0], false);
var errors = new OpenXmlValidator().Validate(document).ToList();
foreach (var error in errors)
{
    Console.Error.WriteLine($"{error.Part?.Uri} {error.Path?.XPath}: {error.Description}");
}

Console.WriteLine($"Open XML schema errors: {errors.Count}");
return errors.Count == 0 ? 0 : 1;
