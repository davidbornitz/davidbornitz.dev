// Import required AWS SDK clients and commands for Node.js
import { PutItemCommand } from "@aws-sdk/client-dynamodb";
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
      alert("You and your dish have been added to the very-exclusive guest list!");
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
// Expose the function to the browser
window.submitData = submitData;
