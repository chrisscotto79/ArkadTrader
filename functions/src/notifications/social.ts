// Notification triggers for the social graph: mentions in posts, replies, likes,
// follows and community joins. Callout notifications live in callouts/messages.ts.

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db } from "../lib/firebase.js";
import { notifyUsers, extractMentions, resolveUsernames, snippet, actorName } from "../lib/notify.js";
import { getCommunity } from "../lib/community.js";
import { REGION, MAX_MENTIONS_PER_ITEM } from "../config.js";

/** posts/{postId} created: notify @mentioned users. */
export const onPostCreated = onDocumentCreated(
  { document: "posts/{postId}", region: REGION },
  async (event) => {
    const post = event.data?.data();
    if (!post) return;
    const authorId: string = post.authorId;
    const content: string = post.content ?? "";
    const listed: string[] = Array.isArray(post.mentions) ? post.mentions : [];
    const usernames = [...new Set([...listed.map((m) => String(m).toLowerCase()), ...extractMentions(content)])].slice(
      0,
      MAX_MENTIONS_PER_ITEM,
    );
    if (usernames.length === 0) return;

    const ids = await resolveUsernames(usernames);
    const who = await actorName(authorId, post.authorUsername);
    await notifyUsers(
      ids.values(),
      {
        type: "mention",
        title: `${who} mentioned you`,
        body: snippet(content),
        data: { route: "post", postId: event.params.postId, userId: authorId },
      },
      { actorId: authorId, dedupeKey: `post_${event.params.postId}` },
    );
  },
);

/** posts/{postId}/comments/{commentId} created: notify the post author, plus @mentions. */
export const onCommentCreated = onDocumentCreated(
  { document: "posts/{postId}/comments/{commentId}", region: REGION },
  async (event) => {
    const comment = event.data?.data();
    if (!comment) return;
    const { postId, commentId } = event.params;
    const authorId: string = comment.authorId;
    const content: string = comment.content ?? "";

    const postSnap = await db.collection("posts").doc(postId).get();
    const postAuthor: string | undefined = postSnap.get("authorId");
    const who = await actorName(authorId, comment.authorUsername);

    if (postAuthor) {
      await notifyUsers(
        [postAuthor],
        {
          type: "reply",
          title: `${who} commented on your post`,
          body: snippet(content),
          data: { route: "post", postId, userId: authorId },
        },
        { actorId: authorId, dedupeKey: `comment_${commentId}` },
      );
    }

    const usernames = extractMentions(content).slice(0, MAX_MENTIONS_PER_ITEM);
    if (usernames.length > 0) {
      const ids = await resolveUsernames(usernames);
      const targets = [...ids.values()].filter((uid) => uid !== postAuthor); // already told about the reply
      await notifyUsers(
        targets,
        {
          type: "mention",
          title: `${who} mentioned you in a comment`,
          body: snippet(content),
          data: { route: "post", postId, userId: authorId },
        },
        { actorId: authorId, dedupeKey: `comment_${commentId}` },
      );
    }
  },
);

/** posts/{postId}/likes/{userId} created: notify the post author (once per liker per post). */
export const onPostLiked = onDocumentCreated(
  { document: "posts/{postId}/likes/{userId}", region: REGION },
  async (event) => {
    const { postId, userId } = event.params;
    const postSnap = await db.collection("posts").doc(postId).get();
    const postAuthor: string | undefined = postSnap.get("authorId");
    if (!postAuthor || postAuthor === userId) return;
    const who = await actorName(userId);
    await notifyUsers(
      [postAuthor],
      {
        type: "like",
        title: `${who} liked your post`,
        body: snippet(postSnap.get("content") ?? ""),
        data: { route: "post", postId, userId },
      },
      { actorId: userId, dedupeKey: `${postId}_${userId}` },
    );
  },
);

/** users/{uid}/followers/{followerId} created: notify uid. */
export const onFollowerAdded = onDocumentCreated(
  { document: "users/{uid}/followers/{followerId}", region: REGION },
  async (event) => {
    const { uid, followerId } = event.params;
    if (uid === followerId) return;
    const who = await actorName(followerId);
    await notifyUsers(
      [uid],
      {
        type: "follow",
        title: `${who} started following you`,
        body: "Tap to see their profile.",
        data: { route: "profile", userId: followerId },
      },
      { actorId: followerId, dedupeKey: `${followerId}` },
    );
  },
);

/**
 * communities/{cid}/members/{uid} created: tell the owner someone joined.
 * Paid joins (the webhook writes `subscriptionStatus`) get a `subscription`
 * notification from the Stripe webhook instead, so they're skipped here.
 */
export const onMemberJoined = onDocumentCreated(
  { document: "communities/{cid}/members/{uid}", region: REGION },
  async (event) => {
    const member = event.data?.data();
    if (!member || member.subscriptionStatus) return;
    const { cid, uid } = event.params;
    const community = await getCommunity(cid);
    const owner = community?.createdBy;
    if (!owner || owner === uid) return;
    const who = await actorName(uid);
    await notifyUsers(
      [owner],
      {
        type: "member_joined",
        title: `${who} joined ${community?.name ?? "your community"}`,
        body: "Say hello in the community.",
        data: { route: "community", communityId: cid, userId: uid },
      },
      { actorId: uid, dedupeKey: `${cid}_${uid}` },
    );
  },
);
