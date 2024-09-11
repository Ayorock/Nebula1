// Add your API endpoint here
var API_ENDPOINT = "https://3mguhroo78.execute-api.us-east-1.amazonaws.com/prod";

// AJAX POST request to save user data
document.getElementById("CreateUser").onclick = function() {
    var inputData = {    
        "firstname": $('#firstName').val(),
        "lastname": $('#lastName').val(),
        "email": $('#email').val(),
        "nationality": $('#nationality').val(),
        "age": $('#age').val(),
        "maritalStatus": $('#maritalStatus').val(),
        "occupation": $('#occupation').val()
    };

    $.ajax({
        url: API_ENDPOINT,
        type: 'POST',
        data:  JSON.stringify(inputData),
        contentType: 'application/json; charset=utf-8',
        success: function (response) {
            document.getElementById("userSaved").innerHTML = "User Data Saved!";
        },
        error: function (xhr, status, error) {
            console.error("Error saving user data:", xhr.responseText);
            alert("Error saving user data: " + error);
        }
    });
};