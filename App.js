import React from 'react';
import {StyleSheet, Text, View} from 'react-native';
import * as watch from 'react-native-watch-connectivity';
import {promisify} from 'es6-promisify';
import {ActionsContainer, Button, FieldsContainer, Fieldset, Form, FormGroup, Input, Label, Switch} from 'react-native-clean-form';

const ignoreError = e => {
    console.trace(e);
    return Promise.resolve(false);
};

export default class App extends React.Component {

    state = {
        isPaired: false,
        isWatchAppInstalled: false,
        watchIsReachable: false,
        watchState: false,
        context: {},
        localContext: {}
    };

    unsubscripe = [];

    constructor(props) {
        super(props);
        this.updateState().catch(ignoreError);
        this.unsubscripe.push(watch.subscribeToApplicationContext((err) => this.updateState().catch(ignoreError)));
        this.unsubscripe.push(watch.subscribeToWatchState((err) => this.updateState().catch(ignoreError)));
        this.unsubscripe.push(watch.subscribeToWatchReachability((err) => this.updateState().catch(ignoreError)));
    }

    componentWillUnmount () {
        for (const unsubscripe of this.unsubscripe) {
            if (typeof unsubscripe === "function") unsubscripe();
        }
    }

    async updateState() {
        const isPaired = await promisify(watch.getIsPaired)().catch(ignoreError);
        const isWatchAppInstalled = await promisify(watch.getIsWatchAppInstalled)().catch(ignoreError);
        const watchIsReachable = await promisify(watch.getWatchReachability)().catch(ignoreError);
        const watchState = await promisify(watch.getWatchState)().catch(ignoreError);
        const context = await watch.getApplicationContext() || {};
        this.setState({...this.state, isPaired, isWatchAppInstalled, watchIsReachable, watchState, context, localContext: {}});
    }

    getContextKey(key) {
        if (this.state.context && this.state.context[key]) return this.state.context[key];
        return "";
    }

    updateLocalContext(which) {
        return (value) => {
            let newLocalContext = this.state.localContext;
            newLocalContext[which] = value;
            this.setState({...this.state, localContext: newLocalContext});
        };
    }

    async save() {
        if (this.state.localContext.delete) {
            await watch.updateApplicationContext({delete: this.state.localContext.delete, pleaseUpdate: new Date().getTime()});
        } else {
            await watch.updateApplicationContext({...this.state.localContext, pleaseUpdate: new Date().getTime()});
        }
    }

    render() {
        return (
            <View style={styles.container}>
                <Text>isPaired: {this.state.isPaired.toString()}</Text>
                <Text>isWatchAppInstalled: {this.state.isWatchAppInstalled.toString()}</Text>
                <Text>watchIsReachable: {this.state.watchIsReachable.toString()}</Text>
                <Text>watchState: {this.state.watchState.toString()}</Text>
                {this.getContextKey("error") && <View>
                    <Text>Error: {JSON.stringify(this.getContextKey("error"))}</Text>
                </View>}
                <Form>
                    <FieldsContainer>
                        <Fieldset label={"Server & School"}>
                            <FormGroup>
                                <Label>School</Label>
                                <Input onChangeText={this.updateLocalContext("school").bind(this)} placeholder={"my-school-identifier"}/>
                            </FormGroup>
                            <FormGroup>
                                <Label>Server</Label>
                                <Input onChangeText={this.updateLocalContext("server").bind(this)} placeholder={"xyz.webuntis.com"}/>
                            </FormGroup>
                        </Fieldset>
                        <Fieldset label={"Credentials"}>
                            <FormGroup>
                                <Label>Username</Label>
                                <Input onChangeText={this.updateLocalContext("username").bind(this)} placeholder={"max.mustermann"}/>
                            </FormGroup>
                            <FormGroup>
                                <Label>Password</Label>
                                <Input type={"password"} onChangeText={this.updateLocalContext("password").bind(this)} placeholder={"my-Sup3rS3cr3tPassw0rd"}/>
                            </FormGroup>
                        </Fieldset>
                        <Fieldset label={"Deleting"}>
                            <FormGroup>
                                <Label>Delete this user</Label>
                                <Input onChangeText={this.updateLocalContext("delete").bind(this)} placeholder={"max.mustermann"}/>
                            </FormGroup>
                        </Fieldset>
                    </FieldsContainer>
                    <ActionsContainer>
                        <Button icon="md-checkmark" iconPlacement="right" onPress={this.save.bind(this)}>Send to Apple Watch</Button>
                    </ActionsContainer>
                </Form>
            </View>
        );
    }
}

const styles = StyleSheet.create({
    container: {
        marginTop: 16,
        flex: 1
    },
});
