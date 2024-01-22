// Import required AWS SDK clients and commands for Node.js
import { PutItemCommand, ScanCommand } from "@aws-sdk/client-dynamodb";
import { PublishCommand } from "@aws-sdk/client-sns";
import { snsClient } from "../libs/snsClient.js";
import { dynamoClient } from "../libs/dynamoClient.js";

export const submitData = async () => {
  //Set the parameters
  // Capture the values entered in each field in the browser (by id).
  const name = document.getElementById("Name").value;
  const number = document.getElementById("Number").value;
  const dish = document.getElementById("Dish").value;
  //Set the table name.
  const tableName = "invitation";

  //Set the parameters for the table
  const params = {
    TableName: tableName,
    // Define the attributes and values of the item to be added. Adding ' + "" ' converts a value to
    // a string.
    Item: {
      Name: { S: name + "" },
      Number: { N: number + "" },
      Dish: { S: dish + "" },
    },
  };
  // Check that all the fields are completed.
  if (name != "" && number != "" && dish != "") {
    try {
      //Upload the item to the table
      await dynamoClient.send(new PutItemCommand(params));
      try {
        // Create the message parameters object.
        const messageParams = {
          Message: "A new guest has been added! \nName:"+name+"\nDish: "+dish+"\nNumber of Guests: "+number ,
          TopicArn: "arn:aws:sns:us-east-2:085879623427:invitation-updates",
        };
        // Send the SNS message
        const data = await snsClient.send(new PublishCommand(messageParams));
        console.log(
          "Success, message published. MessageID is " + data.MessageId,
        );

        const confirmationContainer = document.getElementById("confirmationContainer");

        // Clear existing content in the container
        confirmationContainer.innerHTML = "";

        // Add a message at the top of the container
        const message = document.createElement("p");
        message.textContent = "You're added to the guest list!";
        confirmationContainer.appendChild(message);
      } catch (err) {
        // Display error message if error is not sent
        console.error(err, err.stack);
      }
    } catch (err) {
      // Display error message if item is no added to table
      console.error(
        "An error occurred. Check the console for further information",
        err,
      );
    }
    // Display alert if all field are not completed.
  } else {
    alert("Enter data in each field.");
  }
};

// Function to initialize and display results on page load
const initializeResults = async () => {
  try {
    // Query the table to retrieve all items (you might want to refine this based on your use case)
    const scanParams = {
      TableName: "invitation",
    };
    
    const scanResults = await dynamoClient.send(new ScanCommand(scanParams));
    
    // Log the retrieved items
    console.log("Retrieved items from DynamoDB:", scanResults.Items);
    
    // Display the results on the HTML page
    displayResults(scanResults.Items);
  } catch (err) {
    console.error("Error initializing results:", err);
  }
};

// Function to display results on the HTML page as a table
const displayResults = (items) => {
  const resultsContainer = document.getElementById("resultsContainer");

  // Clear existing content in the container
  resultsContainer.innerHTML = "";


  // Add a message at the top of the container
  const message = document.createElement("p");
  message.textContent = "Here's who is bringing what:";
  resultsContainer.appendChild(message);

  // Create a table element
  const table = document.createElement("table");
  table.border = "1";

  // Create table header
  const headerRow = table.insertRow(0);
  const nameHeader = headerRow.insertCell(0);
  const dishHeader = headerRow.insertCell(1);
  const guestCountHeader = headerRow.insertCell(2);
  nameHeader.textContent = "Name";
  dishHeader.textContent = "Dish";
  guestCountHeader.textContent = "Guest Count";

  // Iterate over the retrieved items and append them to the table
  items.forEach((item) => {
    const row = table.insertRow();
    const nameCell = row.insertCell(0);
    const dishCell = row.insertCell(1);
    const guestCountCell = row.insertCell(2);

    // Populate cells with data from DynamoDB item
    nameCell.textContent = item.Name.S;
    dishCell.textContent = item.Dish.S;
    guestCountCell.textContent = item.Number.N;
  });

  // Append the table to the results container
  resultsContainer.appendChild(table);
};

// Function to handle the submit button click
const handleButtonClick = async () => {
  await submitData(); // Call your existing submitData function to add a new item
  initializeResults(); // Refresh the displayed results
};

// Expose functions to the browser
window.initializeResults = initializeResults;
window.handleButtonClick = handleButtonClick;

// Call initializeResults on page load
document.addEventListener("DOMContentLoaded", initializeResults);

